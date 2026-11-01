using EasytransitCaisse.Data;
using System.ComponentModel.DataAnnotations;
using Microsoft.EntityFrameworkCore;

namespace EasytransitCaisse.Models
{
    // Combos (menus, formules), comme dans le point de vente Odoo : un produit combo a un prix et
    // des groupes de choix (Entrée, Plat, Boisson…) ; chaque choix peut ajouter un supplément.
    public class ComboGroupe : ITenantScoped
    {
        public int Id { get; set; }

        public int TenantId { get; set; }

        public int ProduitId { get; set; }

        [MaxLength(50)]
        public string Nom { get; set; } = "";

        // Nombre d'articles à choisir dans le groupe.
        public int Quantite { get; set; } = 1;

        public int Ordre { get; set; }

        public List<ComboChoix> Choix { get; set; } = new();
    }

    // Produit proposé dans un groupe (supplément ajouté au prix du combo).
    public class ComboChoix
    {
        public int Id { get; set; }

        public int GroupeId { get; set; }

        public int ProduitId { get; set; }

        [Precision(18, 2)]
        public decimal Supplement { get; set; }

        public int Ordre { get; set; }
    }
}
