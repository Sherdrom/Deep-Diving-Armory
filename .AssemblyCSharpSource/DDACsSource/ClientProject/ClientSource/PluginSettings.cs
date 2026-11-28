using System.Globalization;
using System.Xml.Linq;
using Microsoft.Xna.Framework.Input;

namespace DeepDivingArmory;

internal static class PluginSettings
{
    private const string Prefix = "Deep-Diving-Armory";
    private sealed record Entry(string Name, ISetting Setting, LocalizedString Label, LocalizedString Category, LocalizedString? Tooltip);
    private static readonly List<Entry> ordered = [];
    private static readonly ConditionalWeakTable<GUIComponent, object?> menuRows = new();
    private static readonly Dictionary<string, ISetting> registered = new(StringComparer.OrdinalIgnoreCase);

    internal static void Register(ContentPackage package, ISettingsService service)
    {
        ordered.Clear();
        registered.Clear();
        string path = Path.Combine(package.Dir, "Config", "PluginSettings.xml");
        if (!File.Exists(path))
        {
            DebugConsole.AddWarning($"[Deep-Diving-Armory] Missing plugin settings manifest: {path}");
            return;
        }
        XDocument doc;
        try { doc = XDocument.Load(path); }
        catch (Exception e)
        {
            DebugConsole.AddWarning($"[Deep-Diving-Armory] Failed to parse {path}: {e.Message}");
            return;
        }
        foreach (var el in doc.Root?.Element("Settings")?.Elements("Setting") ?? [])
        {
            string? name = (string?)el.Attribute("Name");
            if (string.IsNullOrWhiteSpace(name)) { continue; }
            var entry = Create(el, name);
            if (entry == null) { continue; }
            service.RegisterSetting(entry.Setting);
            ordered.Add(entry);
            registered[name] = entry.Setting;
        }
        service.OverrideUI = BuildUI;
    }

    internal static void Clear()
    {
        foreach (var (row, _) in menuRows)
        {
            if (GUI.KeyboardDispatcher?.Subscriber is GUIComponent focused && row.RectTransform.IsParentOf(focused.RectTransform))
            {
                GUI.KeyboardDispatcher.Subscriber = null;
            }
            // Detaching the dropdown itself unsubscribes it from its highest styled ancestor.
            if (row.GetChild<GUIDropDown>() is { } picker) { picker.RectTransform.Parent = null; }
            row.RectTransform.Parent = null;
        }
        menuRows.Clear();
        ordered.Clear();
        registered.Clear();
    }

    internal static bool TryGet<T>(string name, out T? setting) where T : class, ISetting
    {
        if (registered.TryGetValue(name, out var found) && found is T typed)
        {
            setting = typed;
            return true;
        }
        setting = null;
        return false;
    }

    internal static string GetString(string name, string fallback) =>
        TryGet<BaseSetting<string>>(name, out var s) && s != null ? s.Value : fallback;

    internal static bool GetBool(string name, bool fallback) =>
        TryGet<BooleanSetting>(name, out var s) && s != null ? s.Value : fallback;

    internal static int GetInt(string name, int fallback) =>
        TryGet<IntSetting>(name, out var s) && s != null ? s.Value : fallback;

    internal static float GetFloat(string name, float fallback) =>
        TryGet<FloatSetting>(name, out var s) && s != null ? s.Value : fallback;

    internal static KeyOrMouse GetKey(string name, KeyOrMouse fallback) =>
        TryGet<KeyBindSetting>(name, out var s) && s != null ? s.KeyValue : fallback;

    private static Entry? Create(XElement el, string name)
    {
        string type = ((string?)el.Attribute("Type") ?? "string").Trim().ToLowerInvariant();
        string raw = (string?)el.Attribute("Value") ?? "";
        bool show = !string.Equals((string?)el.Attribute("ShowInMenus"), "false", StringComparison.OrdinalIgnoreCase);
        var id = name.ToIdentifier();
        LocalizedString label = TextManager.Get($"{Prefix}.{name}.DisplayName").Fallback(name);
        LocalizedString category = TextManager.Get($"{Prefix}.{name}.DisplayCategory").Fallback("General");
        // Resolve tooltip lazily so Plugin.Init() works before text packs load.
        LocalizedString tooltip = TextManager.Get($"{Prefix}.{name}.Tooltip").Fallback("");

        ISetting? setting = type switch
        {
            "liststring" => CreateListString(el, id, raw, show, label, tooltip),
            "control" => new KeyBindSetting(id, KeyBindSetting.TryParse(raw, out var parsed) ? parsed : Keys.Escape, label, tooltip) { ShowInUI = show },
            "bool" => new BooleanSetting(id, bool.TryParse(raw, out bool b) && b, label) { ShowInUI = show, ToolTip = tooltip },
            "int" => CreateInt(el, id, raw, show, label, tooltip),
            "float" => CreateFloat(el, id, raw, show, label, tooltip),
            "string" => new StringSetting(id, raw, label) { ShowInUI = show, ToolTip = tooltip },
            _ => null
        };
        if (setting == null)
        {
            DebugConsole.AddWarning($"[Deep-Diving-Armory] Unsupported setting type '{type}' for '{name}'.");
            return null;
        }
        return new Entry(name, setting, label, category, tooltip);
    }

    private static ListStringSetting CreateListString(XElement el, Identifier id, string raw, bool show, LocalizedString label, LocalizedString tooltip)
    {
        string[] choices = el.Element("Values")?.Elements("Value")
            .Select(v => (string?)v.Attribute("Value"))
            .Where(v => !string.IsNullOrWhiteSpace(v))
            .Select(v => v!)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray() ?? [];
        if (choices.Length == 0) { choices = [raw]; }
        string fallback = choices.FirstOrDefault(c => c.Equals(raw, StringComparison.OrdinalIgnoreCase)) ?? choices[0];
        return new ListStringSetting(id, fallback, choices, label, tooltip) { ShowInUI = show };
    }

    private static IntSetting CreateInt(XElement el, Identifier id, string raw, bool show, LocalizedString label, LocalizedString tooltip)
    {
        int defaultVal = int.TryParse(raw, NumberStyles.Integer, CultureInfo.InvariantCulture, out int v) ? v : 0;
        var setting = new IntSetting(id, defaultVal, label) { ShowInUI = show, ToolTip = tooltip };
        int min = int.TryParse((string?)el.Attribute("Min"), NumberStyles.Integer, CultureInfo.InvariantCulture, out int pMin) ? pMin : setting.Range.X;
        int max = int.TryParse((string?)el.Attribute("Max"), NumberStyles.Integer, CultureInfo.InvariantCulture, out int pMax) ? pMax : setting.Range.Y;
        setting.Range = new Point(min, max);
        return setting;
    }

    private static FloatSetting CreateFloat(XElement el, Identifier id, string raw, bool show, LocalizedString label, LocalizedString tooltip)
    {
        float defaultVal = float.TryParse(raw, NumberStyles.Float, CultureInfo.InvariantCulture, out float v) ? v : 0f;
        var setting = new FloatSetting(id, defaultVal, label) { ShowInUI = show, ToolTip = tooltip };
        float min = float.TryParse((string?)el.Attribute("Min"), NumberStyles.Float, CultureInfo.InvariantCulture, out float pMin) ? pMin : setting.Range.X;
        float max = float.TryParse((string?)el.Attribute("Max"), NumberStyles.Float, CultureInfo.InvariantCulture, out float pMax) ? pMax : setting.Range.Y;
        setting.Range = new Vector2(min, max);
        return setting;
    }

    // Match LuaCsForBarotrauma's Mod Settings layout: category headers + 60/40 horizontal rows.
    private static void BuildUI(GUIFrame content)
    {
        var visible = ordered.Where(e => e.Setting.ShowInUI).ToList();
        foreach (var group in visible.GroupBy(e => e.Category.Value))
        {
            var header = new GUITextBlock(new RectTransform((1.0f, 0.06f), content.RectTransform), group.Key,
                font: GUIStyle.SubHeadingFont, textAlignment: Alignment.CenterLeft);
            menuRows.Add(header, null);
            foreach (var entry in group)
            {
                var row = new GUILayoutGroup(new RectTransform((1.0f, 0.07f), content.RectTransform),
                    isHorizontal: true, childAnchor: Anchor.CenterLeft)
                {
                    Stretch = true
                };
                menuRows.Add(row, null);
                string? tipText = entry.Tooltip?.Value;
                LocalizedString? tip = string.IsNullOrEmpty(tipText) ? null : entry.Tooltip;
                new GUITextBlock(new RectTransform((0.6f, 1.0f), row.RectTransform), entry.Label,
                    textAlignment: Alignment.CenterLeft)
                {
                    ToolTip = tip
                };
                AddRowControl(row, entry.Setting, tip);
            }
        }
    }

    private static void AddRowControl(GUILayoutGroup row, ISetting setting, LocalizedString? tip)
    {
        switch (setting)
        {
            case ListStringSetting list:
                list.AddRowControl(row, tip);
                break;
            case KeyBindSetting keyBind:
                keyBind.AddRowControl(row, tip);
                break;
            case BooleanSetting toggle:
            {
                var box = new GUITickBox(new RectTransform((0.4f, 1.0f), row.RectTransform), "")
                {
                    Selected = toggle.PendingValue,
                    ToolTip = tip,
                    OnSelected = tb => { toggle.PendingValue = tb.Selected; return true; }
                };
                box.OnAddedToGUIUpdateList = _ =>
                {
                    box.Selected = toggle.PendingValue;
                    box.Enabled = toggle.CanClientEdit;
                };
                break;
            }
            case IntSetting intSetting:
            {
                var input = new GUINumberInput(new RectTransform((0.4f, 1.0f), row.RectTransform), NumberType.Int)
                {
                    MinValueInt = intSetting.Range.X,
                    MaxValueInt = intSetting.Range.Y,
                    IntValue = intSetting.PendingValue,
                    ToolTip = tip,
                    OnValueChanged = num => intSetting.PendingValue = num.IntValue
                };
                input.OnAddedToGUIUpdateList = _ =>
                {
                    if (!input.TextBox.Selected) { input.IntValue = intSetting.PendingValue; }
                    input.Enabled = intSetting.CanClientEdit;
                };
                break;
            }
            case FloatSetting floatSetting:
            {
                var input = new GUINumberInput(new RectTransform((0.4f, 1.0f), row.RectTransform), NumberType.Float)
                {
                    MinValueFloat = floatSetting.Range.X,
                    MaxValueFloat = floatSetting.Range.Y,
                    FloatValue = floatSetting.PendingValue,
                    ToolTip = tip,
                    OnValueChanged = num => floatSetting.PendingValue = num.FloatValue
                };
                input.OnAddedToGUIUpdateList = _ =>
                {
                    if (!input.TextBox.Selected) { input.FloatValue = floatSetting.PendingValue; }
                    input.Enabled = floatSetting.CanClientEdit;
                };
                break;
            }
            case StringSetting strSetting:
            {
                var textBox = new GUITextBox(new RectTransform((0.4f, 1.0f), row.RectTransform), strSetting.PendingValue)
                {
                    MaxTextLength = strSetting.MaxSize,
                    ToolTip = tip
                };
                typeof(GUITextBox).GetEvent("OnTextChanged")!.AddEventHandler(
                    textBox, (GUITextBox.OnTextChangedHandler)((_, text) => { strSetting.PendingValue = text; return true; }));
                textBox.OnAddedToGUIUpdateList = _ =>
                {
                    if (!textBox.Selected) { textBox.Text = strSetting.PendingValue; }
                    textBox.Enabled = strSetting.CanClientEdit;
                };
                break;
            }
        }
    }
}

internal sealed class ListStringSetting(
    Identifier identifier,
    string defaultValue,
    string[] choices,
    LocalizedString label,
    LocalizedString? tooltip) : BaseSetting<string>(identifier, defaultValue)
{
    public override void Load(XElement element)
    {
        string raw = element.GetAttributeString("value", DefaultValue);
        Value = choices.FirstOrDefault(c => c.Equals(raw, StringComparison.OrdinalIgnoreCase)) ?? DefaultValue;
    }

    public override void Save(XElement element) => element.SetAttributeValue("value", Value);

    internal void AddRowControl(GUILayoutGroup row, LocalizedString? tip)
    {
        var picker = new GUIDropDown(new RectTransform((0.4f, 1.0f), row.RectTransform), elementCount: choices.Length)
        {
            ToolTip = tip
        };
        foreach (string choice in choices)
        {
            picker.AddItem(TextManager.Get($"Deep-Diving-Armory.{Identifier}.{choice}.DisplayName").Fallback(choice), choice);
        }
        picker.SelectItem(PendingValue);
        picker.OnSelected = (_, value) => { PendingValue = (string)value; return true; };
        picker.OnAddedToGUIUpdateList = _ =>
        {
            picker.Enabled = CanClientEdit;
            if (!Equals(picker.SelectedData, PendingValue)) { picker.SelectItem(PendingValue); }
        };
    }

    public override void CreateUI()
    {
        MainUI = new GUIFrame(new RectTransform((1f, 0.07f), null), style: null);
        var row = new GUILayoutGroup(new RectTransform(Vector2.One, MainUI.RectTransform), isHorizontal: true, childAnchor: Anchor.CenterLeft);
        new GUITextBlock(new RectTransform((0.6f, 1f), row.RectTransform), label, textAlignment: Alignment.CenterLeft) { ToolTip = tooltip };
        AddRowControl(row, tooltip);
    }
}

internal sealed class KeyBindSetting : BaseSetting<string>
{
    private readonly KeyOrMouse defaultKey;
    private readonly LocalizedString label;
    private readonly LocalizedString? tooltip;
    public KeyOrMouse KeyValue => TryParse(Value, out var key) ? key : defaultKey;

    public KeyBindSetting(Identifier identifier, KeyOrMouse defaultKey, LocalizedString label, LocalizedString? tooltip)
        : base(identifier, Format(defaultKey))
    {
        this.defaultKey = defaultKey;
        this.label = label;
        this.tooltip = tooltip;
    }

    public override void Load(XElement element)
    {
        string raw = element.GetAttributeString("value", DefaultValue);
        Value = TryParse(raw, out var key) ? Format(key) : DefaultValue;
    }

    public override void Save(XElement element) => element.SetAttributeValue("value", Value);

    internal void AddRowControl(GUILayoutGroup row, LocalizedString? tip)
    {
        bool listening = false;
        bool skipClick = false;
        var button = new GUIButton(new RectTransform((0.4f, 1.0f), row.RectTransform), DisplayName(PendingValue), style: "GUITextBoxNoIcon")
        {
            ToolTip = tip
        };
        button.OnClicked = (_, _) =>
        {
            listening = !listening;
            skipClick = listening;
            button.Selected = listening;
            return true;
        };
        button.OnAddedToGUIUpdateList = _ =>
        {
            button.Enabled = CanClientEdit;
            if (!CanClientEdit && listening)
            {
                listening = false;
                button.Selected = false;
            }
            if (!listening) { button.Text = DisplayName(PendingValue); }
        };
        new GUICustomComponent(new RectTransform(Vector2.Zero, row.RectTransform), onUpdate: (_, _) =>
        {
            if (!listening) { return; }
            if (PlayerInput.PrimaryMouseButtonClicked() && skipClick)
            {
                skipClick = false;
                return;
            }
            var pressed = PlayerInput.GetKeyboardState.GetPressedKeys();
            if (pressed is { Length: > 0 })
            {
                if (pressed.Contains(Keys.Escape))
                {
                    // Prevent Escape from closing the settings menu on the same frame as binding it.
                    var previous = PlayerInput.oldKeyboardState;
                    PlayerInput.oldKeyboardState = new KeyboardState([.. previous.GetPressedKeys(), Keys.Escape],
                        previous.CapsLock, previous.NumLock);
                    SetPending(Keys.Escape);
                    return;
                }
                SetPending(pressed[0]);
                return;
            }
            if (PlayerInput.PrimaryMouseButtonClicked() && (GUI.MouseOn == null || GUI.MouseOn is not GUIButton))
            { SetPending(MouseButton.PrimaryMouse); }
            else if (PlayerInput.SecondaryMouseButtonClicked()) { SetPending(MouseButton.SecondaryMouse); }
            else if (PlayerInput.MidButtonClicked()) { SetPending(MouseButton.MiddleMouse); }
            else if (PlayerInput.Mouse4ButtonClicked()) { SetPending(MouseButton.MouseButton4); }
            else if (PlayerInput.Mouse5ButtonClicked()) { SetPending(MouseButton.MouseButton5); }
            else if (PlayerInput.MouseWheelUpClicked()) { SetPending(MouseButton.MouseWheelUp); }
            else if (PlayerInput.MouseWheelDownClicked()) { SetPending(MouseButton.MouseWheelDown); }
        });

        void SetPending(KeyOrMouse key)
        {
            PendingValue = Format(key);
            button.Text = key.Name;
            listening = false;
            button.Selected = false;
        }
    }

    public override void CreateUI()
    {
        MainUI = new GUIFrame(new RectTransform((1f, 0.07f), null), style: null);
        var row = new GUILayoutGroup(new RectTransform(Vector2.One, MainUI.RectTransform), isHorizontal: true, childAnchor: Anchor.CenterLeft);
        new GUITextBlock(new RectTransform((0.6f, 1f), row.RectTransform), label, textAlignment: Alignment.CenterLeft) { ToolTip = tooltip };
        AddRowControl(row, tooltip);
    }

    private LocalizedString DisplayName(string raw) => (TryParse(raw, out var key) ? key : defaultKey).Name;

    private static string Format(KeyOrMouse key) =>
        key.MouseButton != MouseButton.None ? key.MouseButton.ToString() : key.Key.ToString();

    internal static bool TryParse(string? raw, out KeyOrMouse key)
    {
        if (!string.IsNullOrWhiteSpace(raw) && !int.TryParse(raw, out _))
        {
            if (Enum.TryParse<MouseButton>(raw, ignoreCase: true, out var mouse) && mouse != MouseButton.None)
            {
                key = mouse;
                return true;
            }
            if (Enum.TryParse<Keys>(raw, ignoreCase: true, out var keyboard) && keyboard != Keys.None)
            {
                key = keyboard;
                return true;
            }
        }
        key = default!;
        return false;
    }
}
