namespace Barotrauma.Items.Components
{
    partial class GunsmithData : ItemComponent
    {
        private string savedState = string.Empty;

        [Editable, Serialize("", IsPropertySaveable.Yes)]
        public string SavedState
        {
            get => savedState;
            set => savedState = value ?? string.Empty;
        }

        public GunsmithData(Item item, ContentXElement element) : base(item, element)
        {
            IsActive = false;
        }
    }
}
