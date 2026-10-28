using System.ComponentModel.DataAnnotations;

namespace EasytransitCaisse.Models
{
    // Attribut d'un produit modèle (ex. Taille) et ses valeurs (S, M, L).
    public class ProduitAttribut
    {
        public int Id { get; set; }

        public int ProduitId { get; set; }

        [MaxLength(50)]
        public string Nom { get; set; } = "";

        public int Ordre { get; set; }

        public List<ProduitAttributValeur> Valeurs { get; set; } = new();
    }

    public class ProduitAttributValeur
    {
        public int Id { get; set; }

        public int ProduitAttributId { get; set; }

        [MaxLength(50)]
        public string Valeur { get; set; } = "";

        public int Ordre { get; set; }
    }

    // Combinaison de valeurs d'une variante.
    public class VarianteValeur
    {
        public int VarianteId { get; set; }

        public int ValeurId { get; set; }
    }
}
