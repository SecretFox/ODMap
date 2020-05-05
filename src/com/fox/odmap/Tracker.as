import com.GameInterface.Chat;
import com.GameInterface.DistributedValueBase;
import com.GameInterface.Game.Camera;
import com.GameInterface.Game.Character;
import com.GameInterface.Game.CharacterBase;
import com.GameInterface.Game.Team;
import com.GameInterface.Game.TeamInterface;
import com.GameInterface.MathLib.Vector3;
import com.GameInterface.Nametags;
import com.GameInterface.Tooltip.TooltipData;
import com.GameInterface.Tooltip.TooltipManager;
import com.GameInterface.WaypointInterface;
import com.Utils.Colors;
import com.Utils.ID32;
import com.Utils.Signal;
import com.fox.odmap.MarkerConfig;
import com.fox.odmap.MarkerObject;
import com.fox.odmap.Mod;
import mx.utils.Delegate;
/*
* ...
* @author fox
*/
class com.fox.odmap.Tracker
{
	private var mapRoot:MovieClip;
	private var m_Player:Character;

	// Config
	private var trackerConfig:Array;
	private var XMLFile:XML;

	// Markers
	private var markerArray:Array;
	private var updateInterval:Number;
	private var checkQueue:Array;
	private var checkTimeout;

	// Map data, could be supplied in xml for multiple map support
	private var minX = 160;
	private var maxX = 348;
	private var posToDist;
	private var posToDist2;

	// Stonehenge is perfectly centered circle,no need for Y
	//private var minY = 160;
	//private var maxY = 348;

	private var mapScale;

	private var loadListener:Object;
	public var SignalLoadFailed:Signal;

	public function Tracker(mapclip:MovieClip)
	{
		mapRoot = mapclip;
		m_Player = Character.GetClientCharacter();
		markerArray = [];
		trackerConfig = [];
		checkQueue = [];
		loadListener = new Object();
		loadListener.onLoadComplete  = Delegate.create(this, ImageLoaded);
		loadListener.onLoadError   = Delegate.create(this, ImgFailed);
		SignalLoadFailed = new Signal();
		XMLFile = new XML();
		XMLFile.ignoreWhite = true;
		XMLFile.onLoad = Delegate.create(this, ProcessXML);
	}

	public function Hide()
	{
		for (var i in markerArray) MarkerObject(markerArray[i]).imgClip._visible = false;
	}

	public function Show()
	{
		for (var i in markerArray) MarkerObject(markerArray[i]).imgClip._visible = true;
	}

	public function Start()
	{
		XMLFile.load("ODMap/config.xml");
	}

	private function StartTracking()
	{
		WaypointInterface.SignalPlayfieldChanged.Connect(PlayfieldChanged, this);
		if (!DistributedValueBase.GetDValue("ShowPlayerNametag"))
		{
			AddToQueue(CharacterBase.GetClientCharID());
		}
		if (!DistributedValueBase.GetDValue("ShowVicinityPlayerNametags"))
		{
			var team:Team = TeamInterface.GetClientTeamInfo();
			for (var i in team.m_TeamMembers)
			{
				var teamMember = team.m_TeamMembers[i];
				AddToQueue(teamMember["m_CharacterId"]);
			}
		}
		Nametags.SignalNametagAdded.Connect(AddToQueue, this);
		Nametags.SignalNametagUpdated.Connect(AddToQueue, this);
		Nametags.SignalNametagRemoved.Connect(ClearMarker, this);
		Nametags.RefreshNametags();
	}

	private function PlayfieldChanged()
	{
		if (!Mod.IsODZone()) Disconnect();
	}

	public function Disconnect()
	{
		ClearMarkers();
		WaypointInterface.SignalPlayfieldChanged.Disconnect(PlayfieldChanged, this);
		Nametags.SignalNametagAdded.Disconnect(AddToQueue, this);
		Nametags.SignalNametagUpdated.Disconnect(AddToQueue, this);
		Nametags.SignalNametagRemoved.Disconnect(ClearMarker, this);
		loadListener = undefined;
	}

	private function ProcessXML(success)
	{
		if (success)
		{
			var content:XMLNode = XMLFile.firstChild;
			for (var i = 0; i < content.childNodes.length; i++ )
			{
				var filterNode:XMLNode = content.childNodes[i];
				var config:MarkerConfig = new MarkerConfig();
				config.depth = Number(filterNode.attributes.depth | 0);
				config.scale = Number(filterNode.attributes.scale) || 1;
				config.color1 = filterNode.attributes.color1;
				config.color2 = filterNode.attributes.color2;
				config.rotate = filterNode.attributes.rotate == "true";
				config.keep = filterNode.attributes.keep == "true";
				config.identifier = filterNode.attributes.name+i;
				config.namefilter = filterNode.attributes.namefilter.split(",");
				config.bufffilter = filterNode.attributes.bufffilter.split(",");
				config.img = filterNode.attributes.img;
				trackerConfig.push(config);
			}
			for (var i in trackerConfig)
			{
				var conf:MarkerConfig = trackerConfig[i];
				var clip = mapRoot.getInstanceAtDepth(conf.depth); // allow several entries to use same depth
				if (!clip)
				{
					clip = mapRoot.createEmptyMovieClip(conf.identifier, conf.depth);
				}
				conf.targetClip = clip;
			}
			CalculatePosToPixel();
			ChangeScale();
			StartTracking();
		}
		else
		{
			Chat.SignalShowFIFOMessage.Emit("ODMap: Failed to read config.xml", 0);
			SignalLoadFailed.Emit(true);
		}
		XMLFile = undefined;
	}

	public function CalculatePosToPixel()
	{
		posToDist = mapRoot.Image._width / (maxX - minX);
		for (var i in trackerConfig)
		{
			MarkerConfig(trackerConfig[i]).targetClip._x =  mapRoot.Image._x;
			MarkerConfig(trackerConfig[i]).targetClip._y =  mapRoot.Image._y;
		}
	}

	public function ChangeScale()
	{
		mapScale = mapRoot.Image._width / 200;
		for (var i in markerArray)
		{
			var marker:MarkerObject = markerArray[i];
			marker.imgClip._xscale = marker.imgClip._yscale = marker.config.scale * mapScale * 100;
			marker.imgClip._x  = -marker.imgClip._width / 2;
			marker.imgClip._y = -marker.imgClip._height / 2;
		}
	}

	private function AddToQueue(id:ID32)
	{
		checkQueue.push(id);
		clearTimeout(checkTimeout);
		checkTimeout = setTimeout(Delegate.create(this, CheckTag), 100);
	}

	private function CheckTag()
	{
		while (checkQueue.length>0)
		{
			var id:ID32 = ID32(checkQueue.pop());
			var char:Character = new Character(id);
			var found;
			for (var i in markerArray)
			{
				var marker:MarkerObject = markerArray[i];
				if (marker.char.GetID().toString() == id.toString())
				{
					found = true;
					break
				}
			}
			if (!found)
			{
				if (id.IsPlayer())
				{
					AddMarker(char,trackerConfig[0]);
				}
				else
				{
					var name:String = char.GetName();
					if (name != "GHOST")
					{
						for (var i = 1; i < trackerConfig.length; i++)
						{
							var config:MarkerConfig = trackerConfig[i];
							if (!config.namefilter && !config.bufffilter)
							{
								AddMarker(char, trackerConfig[i]);
								break;
							}
							else
							{
								for (var x in config.namefilter)
								{
									if (name.indexOf(config.namefilter[x]) >= 0)
									{
										AddMarker(char, config);
										i = trackerConfig.length;
										break
									}
								}
								for (var x in config.bufffilter)
								{
									if (char.m_BuffList[config.bufffilter[x]])
									{
										AddMarker(char, config);
										i = trackerConfig.length;
										break
									}
									else if (char.m_InvisibleBuffList[config.bufffilter[x]])
									{
										AddMarker(char, config);
										i = trackerConfig.length;
										break
									}
								}
							}
						}
					}
				}
			}
		}
	}

	private function ImgFailed(img:MovieClip)
	{
		for (var i in markerArray)
		{
			if (MarkerObject(markerArray[i]).imgClip == img)
			{
				Chat.SignalShowFIFOMessage.Emit("ODMap: Failed to load img " + markerArray[i].config.img, 0);
				break;
			}
		}

	}

	private function ImageLoaded(img)
	{
		img._x = -img._width / 2;
		img._y = -img._height / 2;
		clearInterval(updateInterval);
		updateInterval = setInterval(Delegate.create(this, MoveMarkers), 50);
		MoveMarkers();
	}

	private function AddMarker(char:Character, config:MarkerConfig)
	{
		var imgLoader:MovieClipLoader = new MovieClipLoader();
		imgLoader.addListener(loadListener);
		var marker:MarkerObject = new MarkerObject();
		marker.containerClip = config.targetClip.createEmptyMovieClip(char.GetID().toString(), config.targetClip.getNextHighestDepth());
		marker.imgClip = marker.containerClip.createEmptyMovieClip("img", marker.containerClip.getNextHighestDepth());
		if (char.IsClientChar()) marker.client = true;
		marker.char = char;
		marker.config = config;

		marker.containerClip.onRollOver =  function()
		{
			if (this._visible && this._alpha > 0)
			{
				var tooltipData:TooltipData = new TooltipData();
				var str:String =  char.GetName();
				if (char.IsNPC())
				{
					for (var i in char.m_BuffList)
					{
						str += "\n" + char.m_BuffList[i].m_Name;
					}
				}
				tooltipData.m_Descriptions.push(str);
				tooltipData.m_Padding = 4;
				tooltipData.m_MaxWidth = 140;
				this.m_Tooltip = TooltipManager.GetInstance().ShowTooltip( undefined, undefined, 0, tooltipData );
			}
		}

		marker.containerClip.onRollOut = function()
		{
			if (this.m_Tooltip != undefined)
			{
				this.m_Tooltip.Close();
				this.m_Tooltip = undefined;
			}
		}

		if (config.color1)
		{
			if (config.color1 == config.color2 || !config.color2)
			{
				Colors.ApplyColor(marker.imgClip, config.color1);
			}
			else
			{
				if (char.GetOffensiveTarget().IsPlayer())
				{
					Colors.ApplyColor(marker.imgClip, config.color2);
				}
				else
				{
					Colors.ApplyColor(marker.imgClip,  config.color1);
				}
				marker.slot = marker.char.SignalOffensiveTargetChanged.Connect(this, Delegate.create(this,function()
				{
					if (!marker.char.GetOffensiveTarget().IsPlayer()) Colors.ApplyColor(marker.imgClip,  config.color1);
					else Colors.ApplyColor(marker.imgClip, config.color2);
				}));
			}
		}
		marker.imgClip._xscale = marker.imgClip._yscale = config.scale * mapScale * 100;
		markerArray.push(marker);
		imgLoader.loadClip(config.img, marker.imgClip);
	}

	public function MoveMarkers()
	{
		for (var i in markerArray)
		{
			var marker:MarkerObject = markerArray[i];
			if (marker.char.IsDead() && !marker.config.keep)
			{
				ClearMarker(marker.char.GetID());
				break;
			}
			var pos:Vector3 = marker.char.GetPosition();
			marker.containerClip._x = (pos.x - minX) * posToDist;
			marker.containerClip._y = (maxX - pos.z) * posToDist;
			if (marker.containerClip.hitTest(mapRoot.Image))
			{
				marker.containerClip._visible = true;
			}
			else
			{
				marker.containerClip._visible = false;
			}
			if (marker.config.rotate)
			{
				if (marker.client) marker.containerClip._rotation = -Camera.m_AngleY * 57.3;
				else marker.containerClip._rotation = -marker.char.GetRotation() * 57.3;
			}
		}
	}

	private function ClearMarker(id:ID32)
	{
		if id.IsPlayer() return;
		for (var i in markerArray)
		{
			var marker:MarkerObject = markerArray[i];
			if (marker.char.GetID().toString() == id.toString())
			{
				marker.char.SignalOffensiveTargetChanged.DisconnectSlot(marker.slot);
				marker.containerClip.m_Tooltip.Close();
				marker.containerClip.removeMovieClip();
				delete markerArray[i];
				if (markerArray.length == 0)
				{
					clearInterval(updateInterval);
				}
				break
			}
		}
	}

	public function ClearMarkers()
	{
		clearInterval(updateInterval);
		clearTimeout(checkTimeout);
		for (var i in markerArray)
		{
			var marker:MarkerObject = markerArray[i];
			marker.char.SignalOffensiveTargetChanged.DisconnectSlot(marker.slot);
			marker.containerClip.removeMovieClip()
		}
		markerArray = new Array();
	}

}