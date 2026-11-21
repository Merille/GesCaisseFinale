namespace GesCaisse.Models
{
    public class ClientIndexViewModel
    {
        public List<Client> Clients { get; set; } = new();
        public int CurrentPage { get; set; } = 1;
        public int TotalPages { get; set; } = 1;
        public int TotalCount { get; set; } = 0;
        public string Search { get; set; } = "";
    }
}
