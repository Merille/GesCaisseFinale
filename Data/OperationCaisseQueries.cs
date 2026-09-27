using EasytransitCaisse.Models;

namespace EasytransitCaisse.Data
{
    public static class OperationCaisseQueries
    {
        public const string StatutRejete = "Rejeté";

        // Une opération rejetée n'a pas eu lieu : elle reste visible dans les
        // listes mais n'entre dans aucun total, solde ni export comptable.
        public static IQueryable<OperationCaisse> NonRejetees(this IQueryable<OperationCaisse> operations)
            => operations.Where(o => o.StatutValidation != StatutRejete);

        public static IEnumerable<OperationCaisse> NonRejetees(this IEnumerable<OperationCaisse> operations)
            => operations.Where(o => o.StatutValidation != StatutRejete);
    }
}
