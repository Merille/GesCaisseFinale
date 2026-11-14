using System.Security.Cryptography;
using System.Text;

namespace EasytransitCaisse.Services
{
    // Mots de passe : PBKDF2-HMAC-SHA512 salé, format commun aux versions .NET et PHP :
    // « pbkdf2_sha512$itérations$sel$empreinte » (sel de 16 octets, empreinte de 64 octets, en Base64).
    // Ancien format encore accepté à la connexion puis remplacé : Base64(SHA-256) sans sel.
    // (Le format bcrypt de la version PHP n'est pas lu ici : l'utilisateur doit alors redéfinir son mot de passe.)
    public static class MotsDePasse
    {
        public const int Iterations = 210000;
        private const string Prefixe = "pbkdf2_sha512$";

        public static string Hacher(string motDePasse)
        {
            var sel = RandomNumberGenerator.GetBytes(16);
            var empreinte = Rfc2898DeriveBytes.Pbkdf2(Encoding.UTF8.GetBytes(motDePasse), sel, Iterations, HashAlgorithmName.SHA512, 64);
            return $"{Prefixe}{Iterations}${Convert.ToBase64String(sel)}${Convert.ToBase64String(empreinte)}";
        }

        public static bool Verifier(string motDePasse, string? hash)
        {
            hash ??= "";
            if (hash.StartsWith(Prefixe, StringComparison.Ordinal))
            {
                var p = hash.Split('$');
                if (p.Length != 4 || !int.TryParse(p[1], out var iterations) || iterations < 1000 || iterations > 5000000) return false;
                try
                {
                    var sel = Convert.FromBase64String(p[2]);
                    var attendu = Convert.FromBase64String(p[3]);
                    if (attendu.Length == 0) return false;
                    var calcule = Rfc2898DeriveBytes.Pbkdf2(Encoding.UTF8.GetBytes(motDePasse), sel, iterations, HashAlgorithmName.SHA512, attendu.Length);
                    return CryptographicOperations.FixedTimeEquals(calcule, attendu);
                }
                catch (FormatException) { return false; }
            }
            if (hash == "" || hash.StartsWith('$')) return false;
            // Ancien format : Base64(SHA-256(mot de passe)), sans sel.
            var ancien = Encoding.ASCII.GetBytes(Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(motDePasse))));
            return CryptographicOperations.FixedTimeEquals(ancien, Encoding.ASCII.GetBytes(hash));
        }

        // Le mot de passe enregistré est-il dans un ancien format (à remplacer à la prochaine connexion) ?
        public static bool AMettreANiveau(string? hash) => !(hash ?? "").StartsWith($"{Prefixe}{Iterations}$", StringComparison.Ordinal);

        // Empreinte factice : même calcul pour un utilisateur inconnu (le temps de réponse ne révèle pas si le compte existe).
        public const string Factice = "pbkdf2_sha512$210000$AAAAAAAAAAAAAAAAAAAAAA==$AAAA";
    }
}
