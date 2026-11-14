using System.ComponentModel.DataAnnotations;

namespace EasytransitCaisse.Models
{
    // Échec de connexion récent (nom d'utilisateur saisi, adresse IP) : limite des tentatives.
    // Pas rattaché à une société (on ne la connaît pas avant la connexion). Comme TentativesConnexion en PHP.
    public class TentativeConnexion
    {
        public int Id { get; set; }

        [StringLength(100)]
        public string NomUtilisateur { get; set; } = "";

        [StringLength(45)]
        public string AdresseIp { get; set; } = "";

        public DateTime DateTentative { get; set; }
    }
}
