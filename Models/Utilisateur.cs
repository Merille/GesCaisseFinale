namespace EasytransitCaisse.Models
{
    // Profil "SuperAdmin" => TenantId = null (portée globale, gère les sociétés/tenants).
    // Nullable (contrairement aux autres entités) car TenantId = 0 n'a pas de tenant
    // correspondant : une FK obligatoire vers Tenants rejetterait la valeur.
    public class Utilisateur
    {
        public int Id { get; set; }

        public string NomUtilisateur { get; set; }

        public string MotPasse { get; set; }

        public string NomComplet { get; set; }

        [System.ComponentModel.DataAnnotations.StringLength(50)]
        public string Profil { get; set; }

        // Profil de la société (droits d'accès) ; null pour Admin et SuperAdmin (tous les droits).
        public int? ProfilId { get; set; }

        // Droit : autorise cet utilisateur à passer une opération de caisse à
        // "Validé"/"Rejeté" (sinon elle reste forcée à "En attente", y compris
        // si la valeur est falsifiée côté client — vérifié aussi côté serveur).
        public bool PeutValiderOperations { get; set; }

        // Droit d'accorder des remises au point de vente (sur un article et globale), avec un
        // pourcentage maximal facultatif (null : sans limite). Les administrateurs l'ont toujours.
        public bool PeutRemise { get; set; }

        [Microsoft.EntityFrameworkCore.Precision(5, 2)]
        public decimal? RemiseMax { get; set; }

        public int? TenantId { get; set; }

        public virtual Tenant? Tenant { get; set; }
    }
}
