using System.Globalization;

namespace EasytransitCaisse.Services
{
    public static class MontantHelper
    {
        // Analyse un montant saisi indépendamment de la culture du serveur :
        // un <input type="number"> envoie toujours un point décimal, quelle
        // que soit la culture ambiante (ici française), sous laquelle un
        // binding decimal direct échouerait silencieusement et retomberait
        // à 0 dès que la valeur contient un point.
        public static decimal Parse(string? valeur)
        {
            return decimal.TryParse(
                (valeur ?? "0").Replace(',', '.'),
                NumberStyles.Any,
                CultureInfo.InvariantCulture,
                out var v) ? v : 0;
        }
    }
}
