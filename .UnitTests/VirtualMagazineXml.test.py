"""Check the single-player 5.56 pilot's ammo references and consumption wiring."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

expected = {
    "deep_5.56x45": (30, "5.56x45round"),
    "deep_5.56x45_tit": (30, "5.56x45round_tit"),
    "deep_5.56x45_phy": (30, "5.56x45round_phy"),
    "deep_556x45_M995": (30, "556x45round_M995"),
    "deep_556x45_SSA_AP": (30, "556x45round_SSA_AP"),
    "deep_556x45_du": (30, "556x45round_depleted_uranium"),
    "deep_5.56x45_expansion": (60, "5.56x45round"),
    "deep_556x45_expansion_tit": (60, "5.56x45round_tit"),
    "deep_556x45_expansion_phy": (60, "5.56x45round_phy"),
}
magazines = ET.parse("weapon/rifle/rifle_mag.xml").getroot()
rounds = {item.get("identifier"): item for item in ET.parse("weapon/rifle/rifle_round.xml").getroot()}
refill = Path("Lua/Scripts/PeachTechnology/ContainerConditionTransfer.lua").read_text()
found = set()
for item in magazines:
    component = item.find("VirtualizedMagazine")
    if component is None:
        continue
    item_id = item.get("identifier")
    size, ammo_id = expected[item_id]
    found.add(item_id)
    assert int(item.get("health")) == int(component.get("MaxSize")) == size
    assert component.get("ProjectileIdentifiers").split(",") == [ammo_id] * size
    assert component.get("AllowedAmmoTags") in rounds[ammo_id].get("tags").split(",")
    assert "556mag" in item.get("tags").split(",")
    assert item.find("ItemContainer") is None, "old ammo container still consumes condition"
assert found == expected.keys()
assert magazines.find("Item[@identifier='deep_556x45_vhs']/ItemContainer") is not None

sources = {item.get("identifier") for item in ET.parse("weapon/ammo/ammobox.xml").getroot()}
refill_ammo = dict(re.findall(r'\["(ammobox[^"]*)"\]\s*=\s*"([^"]+)"', refill))
assert len(refill_ammo) == 6 and refill_ammo.keys() <= sources
assert set(refill_ammo.values()) == {ammo_id for _, ammo_id in expected.values()}

weapon = ET.parse("weapon/rifle/rifle_phy/hk416.xml").getroot().find("Item")
gun = weapon.find("SwitchableRangedWeapon")
assert gun.get("switchableSlots") == "0,1"
main_use = [effect for effect in gun.findall("StatusEffect")
            if effect.get("type") == "OnUse" and effect.get("targetslot") == "0"
            and effect.find("Use") is not None]
assert len(main_use) == 1, "each primary shot must consume the magazine once"
assert main_use[0].find("Conditional").get("currentProjectileSelected") == "eq 0"
assert weapon.find("ItemContainer/Containable").get("items").split(",")[-1] == "556mag"
print("ok: nine 5.56 magazines, whitelist/refill mappings and HK416 primary/underbarrel slots")
