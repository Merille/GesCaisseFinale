using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace GesCaisse.AgentImpression;

// Agent d'impression GesCaisse.
//
// Un navigateur ne peut pas ouvrir une connexion vers une imprimante réseau ESC/POS (port 9100).
// L'agent, installé sur le poste de caisse, écoute sur http://127.0.0.1:9101 (ce poste uniquement) :
// l'écran de vente lui envoie le bon déjà mis en forme (octets ESC/POS) et l'adresse de l'imprimante,
// l'agent le transmet à l'imprimante. Il joue le rôle de l'« IoT Box » d'autres logiciels de caisse.
//
//   GET  /etat      → { ok, version }
//   POST /imprimer  { ip, port, donnees (base64) } → { ok } ou { ok: false, erreur }
//
// Sécurité : écoute locale seulement ; imprimantes du réseau local seulement (adresses privées) ; ports
// d'imprimante autorisés (9100 à 9109 par défaut) ; option --origine pour n'accepter que l'adresse de GesCaisse.
//
// Options : --port 9101   --origine https://caisse.exemple.com (répétable)   --ports-imprimantes 9100,9101
public static class Program
{
    const string Version = "1.0.0";
    const int TailleMax = 1024 * 1024;

    static int _port = 9101;
    static readonly List<string> _origines = new();
    static readonly HashSet<int> _portsImprimantes = Enumerable.Range(9100, 10).ToHashSet();
    static string _journal = "";

    public static async Task<int> Main(string[] args)
    {
        for (var i = 0; i < args.Length; i++)
        {
            var valeur = i + 1 < args.Length ? args[i + 1] : "";
            switch (args[i])
            {
                case "--port" when int.TryParse(valeur, out var p): _port = p; i++; break;
                case "--origine": _origines.Add(valeur.TrimEnd('/')); i++; break;
                case "--ports-imprimantes":
                    _portsImprimantes.Clear();
                    foreach (var x in valeur.Split(',', StringSplitOptions.RemoveEmptyEntries))
                        if (int.TryParse(x, out var pi)) _portsImprimantes.Add(pi);
                    i++;
                    break;
            }
        }
        _portsImprimantes.Remove(_port);   // jamais vers l'agent lui-même
        _journal = Path.Combine(AppContext.BaseDirectory, "agent-impression.log");

        TcpListener ecoute;
        try
        {
            ecoute = new TcpListener(IPAddress.Loopback, _port);
            ecoute.Start();
        }
        catch (SocketException e)
        {
            Noter($"Démarrage impossible sur le port {_port} : {e.Message} (agent déjà lancé ?)");
            return 1;
        }
        Noter($"Agent d'impression GesCaisse {Version} : http://127.0.0.1:{_port}"
              + (_origines.Count > 0 ? " · origines : " + string.Join(", ", _origines) : " · toutes origines"));
        while (true)
        {
            var client = await ecoute.AcceptTcpClientAsync();
            _ = Task.Run(() => TraiterAsync(client));
        }
    }

    static void Noter(string texte)
    {
        var ligne = $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} {texte}";
        Console.WriteLine(ligne);
        try
        {
            if (File.Exists(_journal) && new FileInfo(_journal).Length > 1_000_000) File.Delete(_journal);
            File.AppendAllText(_journal, ligne + Environment.NewLine);
        }
        catch { /* journal facultatif */ }
    }

    // ------------------------------------------------------------------
    // HTTP minimal (une requête par connexion)
    // ------------------------------------------------------------------
    static async Task TraiterAsync(TcpClient client)
    {
        using var _ = client;
        client.ReceiveTimeout = client.SendTimeout = 15000;
        var flux = client.GetStream();
        try
        {
            var (methode, chemin, entetes, corps) = await LireAsync(flux);
            var origine = entetes.GetValueOrDefault("origin", "");
            // État de l'agent : consultable aussi depuis la barre d'adresse du navigateur (sans origine).
            var origineAdmise = _origines.Count == 0 || _origines.Contains(origine.TrimEnd('/'), StringComparer.OrdinalIgnoreCase)
                || (origine == "" && methode == "GET" && (chemin == "/etat" || chemin == "/"));
            if (methode == "OPTIONS")
            {
                await RepondreAsync(flux, origineAdmise ? 204 : 403, null, origine, origineAdmise);
                return;
            }
            if (!origineAdmise)
            {
                Noter($"Refusé : origine {origine} non autorisée");
                await RepondreAsync(flux, 403, Rep(false, "origine non autorisée par l'agent d'impression"), origine, false);
                return;
            }
            if (methode == "GET" && (chemin == "/etat" || chemin == "/"))
            {
                await RepondreAsync(flux, 200, Rep(true, null, _portsImprimantes.OrderBy(p => p).ToArray()), origine, true);
                return;
            }
            if (methode == "POST" && chemin == "/imprimer")
            {
                var (code, reponse) = await ImprimerAsync(corps);
                await RepondreAsync(flux, code, reponse, origine, true);
                return;
            }
            await RepondreAsync(flux, 404, Rep(false, "adresse inconnue"), origine, true);
        }
        catch (Exception e)
        {
            try { await RepondreAsync(flux, 400, Rep(false, "requête invalide : " + e.Message), "", false); } catch { }
        }
    }

    static async Task<(string, string, Dictionary<string, string>, byte[])> LireAsync(NetworkStream flux)
    {
        var tampon = new List<byte>();
        var octet = new byte[1];
        // En-têtes : jusqu'à la ligne vide.
        while (true)
        {
            if (await flux.ReadAsync(octet) == 0) throw new IOException("connexion fermée");
            tampon.Add(octet[0]);
            if (tampon.Count > 16384) throw new IOException("en-têtes trop longs");
            var n = tampon.Count;
            if (n >= 4 && tampon[n - 4] == '\r' && tampon[n - 3] == '\n' && tampon[n - 2] == '\r' && tampon[n - 1] == '\n') break;
        }
        var lignes = Encoding.ASCII.GetString(tampon.ToArray()).Split("\r\n");
        var premiere = lignes[0].Split(' ');
        var entetes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var l in lignes.Skip(1))
        {
            var i = l.IndexOf(':');
            if (i > 0) entetes[l[..i].Trim().ToLowerInvariant()] = l[(i + 1)..].Trim();
        }
        var longueur = int.TryParse(entetes.GetValueOrDefault("content-length"), out var lg) ? lg : 0;
        if (longueur < 0 || longueur > TailleMax) throw new IOException("bon trop volumineux");
        var corps = new byte[longueur];
        var lu = 0;
        while (lu < longueur)
        {
            var r = await flux.ReadAsync(corps.AsMemory(lu));
            if (r == 0) throw new IOException("bon incomplet");
            lu += r;
        }
        var chemin = premiere.Length > 1 ? premiere[1].Split('?')[0] : "/";
        return (premiere[0].ToUpperInvariant(), chemin, entetes, corps);
    }

    static async Task RepondreAsync(NetworkStream flux, int code, byte[]? contenu, string origine, bool cors)
    {
        var corps = contenu ?? Array.Empty<byte>();
        var texte = code switch { 200 => "OK", 204 => "No Content", 400 => "Bad Request", 403 => "Forbidden", 404 => "Not Found", _ => "Bad Gateway" };
        var sb = new StringBuilder();
        sb.Append($"HTTP/1.1 {code} {texte}\r\n");
        if (cors && origine != "")
        {
            // CORS et accès au réseau privé (Chrome / Edge) : la page GesCaisse peut appeler l'agent local.
            sb.Append($"Access-Control-Allow-Origin: {origine}\r\nVary: Origin\r\n");
            sb.Append("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\n");
            sb.Append("Access-Control-Allow-Private-Network: true\r\nAccess-Control-Max-Age: 600\r\n");
        }
        if (contenu != null) sb.Append("Content-Type: application/json; charset=utf-8\r\n");
        sb.Append($"Content-Length: {corps.Length}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n");
        await flux.WriteAsync(Encoding.ASCII.GetBytes(sb.ToString()));
        if (corps.Length > 0) await flux.WriteAsync(corps);
        await flux.FlushAsync();
    }

    // ------------------------------------------------------------------
    // Impression
    // ------------------------------------------------------------------
    record Demande(string? ip, int? port, string? donnees);

    // JSON sans réflexion (exécutable réduit) : lecture par JsonDocument, écriture par Utf8JsonWriter.
    static Demande? LireDemande(byte[] corps)
    {
        using var doc = JsonDocument.Parse(corps);
        var r = doc.RootElement;
        string? Texte(string nom) => r.TryGetProperty(nom, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() : null;
        int? port = r.TryGetProperty("port", out var p) && p.ValueKind == JsonValueKind.Number && p.TryGetInt32(out var n) ? n : null;
        return new Demande(Texte("ip"), port, Texte("donnees"));
    }

    static byte[] Rep(bool ok, string? erreur = null, int[]? ports = null)
    {
        using var m = new MemoryStream();
        using (var w = new Utf8JsonWriter(m))
        {
            w.WriteStartObject();
            w.WriteBoolean("ok", ok);
            if (erreur != null) w.WriteString("erreur", erreur);
            if (ports != null)
            {
                w.WriteString("version", Version);
                w.WriteStartArray("portsImprimantes");
                foreach (var x in ports) w.WriteNumberValue(x);
                w.WriteEndArray();
            }
            w.WriteEndObject();
        }
        return m.ToArray();
    }

    static async Task<(int, byte[])> ImprimerAsync(byte[] corps)
    {
        var d = LireDemande(corps);
        if (d == null || string.IsNullOrWhiteSpace(d.ip) || string.IsNullOrEmpty(d.donnees))
            return (400, Rep(false, "imprimante ou bon manquant"));
        var port = d.port ?? 9100;
        if (!_portsImprimantes.Contains(port))
            return (400, Rep(false, $"port {port} non autorisé par l'agent (ports admis : {string.Join(", ", _portsImprimantes.OrderBy(p => p))})"));
        byte[] octets;
        try { octets = Convert.FromBase64String(d.donnees); }
        catch { return (400, Rep(false, "bon illisible")); }

        IPAddress? adresse;
        try
        {
            adresse = IPAddress.TryParse(d.ip.Trim(), out var a) ? a
                : (await Dns.GetHostAddressesAsync(d.ip.Trim())).FirstOrDefault(x => x.AddressFamily == AddressFamily.InterNetwork);
        }
        catch { adresse = null; }
        if (adresse == null)
            return (502, Rep(false, $"adresse {d.ip} introuvable"));
        if (!AdresseLocale(adresse))
            return (400, Rep(false, $"{adresse} n'est pas une adresse du réseau local"));

        try
        {
            using var imprimante = new TcpClient();
            using var delai = new CancellationTokenSource(TimeSpan.FromSeconds(8));
            await imprimante.ConnectAsync(adresse, port, delai.Token);
            var flux = imprimante.GetStream();
            await flux.WriteAsync(octets, delai.Token);
            await flux.FlushAsync(delai.Token);
            imprimante.Client.Shutdown(SocketShutdown.Send);
            Noter($"Bon imprimé sur {adresse}:{port} ({octets.Length} octets)");
            return (200, Rep(true));
        }
        catch (OperationCanceledException)
        {
            Noter($"Échec {adresse}:{port} : pas de réponse");
            return (502, Rep(false, $"imprimante {adresse}:{port} sans réponse (allumée, branchée au réseau ?)"));
        }
        catch (SocketException e)
        {
            Noter($"Échec {adresse}:{port} : {e.Message}");
            return (502, Rep(false, $"imprimante {adresse}:{port} injoignable ({e.SocketErrorCode})"));
        }
    }

    // Réseau local uniquement : 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 (et ce poste).
    static bool AdresseLocale(IPAddress a)
    {
        if (IPAddress.IsLoopback(a)) return true;
        if (a.AddressFamily != AddressFamily.InterNetwork) return a.IsIPv6LinkLocal || a.IsIPv6UniqueLocal;
        var b = a.GetAddressBytes();
        return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168) || (b[0] == 169 && b[1] == 254);
    }
}
