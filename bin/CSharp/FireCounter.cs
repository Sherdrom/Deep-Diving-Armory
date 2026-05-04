using System;
using System.Xml.Linq;
using Microsoft.Xna.Framework;
using Barotrauma;
using Barotrauma.Networking;
using SRW;

namespace Barotrauma.Items.Components
{
    partial class FireCounter : ItemComponent, IServerSerializable
    {
        private int fireCount;
        private bool wasUsedLastFrame;

        [Editable(MinValueInt = 0), Serialize(0, IsPropertySaveable.Yes, description: "记录枪械的总开火次数")]
        public int FireCount
        {
            get { return fireCount; }
            set { fireCount = value; }
        }

        public FireCounter(Item item, ContentXElement element) : base(item, element)
        {
            IsActive = true;
        }

        public override void Update(float deltaTime, Camera cam)
        {
            var switchableRangedWeapon = item.GetComponent<SwitchableRangedWeapon>();
            if (switchableRangedWeapon == null) { return; }

            if (switchableRangedWeapon.WasUsed && !wasUsedLastFrame)
            {
                fireCount++;
#if SERVER
                item.CreateServerEvent(this);
#endif
            }
            wasUsedLastFrame = switchableRangedWeapon.WasUsed;
        }

#if SERVER
        public void ServerEventWrite(IWriteMessage msg, Client c, NetEntityEvent.IData extraData = null)
        {
            msg.Write(fireCount);
        }
#endif

#if CLIENT
        public void ClientEventRead(IReadMessage msg, float sendingTime)
        {
            fireCount = msg.ReadInt32();
        }

        public override void AddTooltipInfo(ref LocalizedString name, ref LocalizedString description)
        {
            string colorStr = XMLExtensions.ColorToString(GUIStyle.Orange);
            description += $"\n  ‖color:{colorStr}‖开火次数: {fireCount}‖color:end‖";
        }
#endif

        public override XElement Save(XElement parentElement)
        {
            XElement componentElement = base.Save(parentElement);
            return componentElement;
        }
    }
}
