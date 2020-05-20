import com.GameInterface.Chat;
import com.GameInterface.DistributedValueBase;
import com.GameInterface.Game.Camera;
import com.GameInterface.Game.Character;
import com.GameInterface.Game.CharacterBase;
import com.GameInterface.Game.Team;
import com.GameInterface.Game.TeamInterface;
import com.GameInterface.MathLib.Vector3;
import com.GameInterface.Nametags;
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
	static var markerArray:Array;
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
		if (!Mod.IsStoneHenge(com.GameInterface.Game.Character.GetClientCharacter().GetPlayfieldID)) Disconnect();
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
				config.deathTooltip = filterNode.attributes.deathTooltip == "true";
				config.identifier = filterNode.attributes.name+i;
				config.namefilter = filterNode.attributes.namefilter.split(",");
				config.bufffilter = filterNode.attributes.bufffilter.split(",");
				config.iimg = filterNode.attributes.iimg;
				config.eimg = filterNode.attributes.eimg;
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
					AddEnemyTag(char);
				}
			}
		}
	}

	private function AddEnemyTag(char:Character)
	{
		var name:String = char.GetName();
		if (name != "GHOST") // Invisible being inside the hag stone
		{
			for (var i = 1; i < trackerConfig.length; i++)
			{
				var config:MarkerConfig = trackerConfig[i];
				if (!config.namefilter && !config.bufffilter)
				{
					AddMarker(char, trackerConfig[i]);
					return;
				}
				else
				{
					for (var x in config.namefilter)
					{
						if (name.indexOf(config.namefilter[x]) >= 0)
						{
							AddMarker(char, config);
							return;
						}
					}
					for (var x in config.bufffilter)
					{
						if (char.m_BuffList[config.bufffilter[x]] || char.m_InvisibleBuffList[config.bufffilter[x]])
						{
							AddMarker(char, config);
							return;
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
	}

	private function AddMarker(char:Character, config:MarkerConfig)
	{
	//init
		var imgLoader:MovieClipLoader;
		var marker:MarkerObject = new MarkerObject();
		if (char.IsClientChar()) marker.client = true;
		marker.char = char;
		marker.config = config;
		marker.containerClip = config.targetClip.createEmptyMovieClip(char.GetID().toString(), config.targetClip.getNextHighestDepth());
		markerArray.push(marker);
		// external image
		if (config.eimg)
		{
			imgLoader = new MovieClipLoader();
			imgLoader.addListener(loadListener);
			marker.imgClip = marker.containerClip.createEmptyMovieClip("img", marker.containerClip.getNextHighestDepth());
			marker.imgClip._xscale = marker.imgClip._yscale = config.scale * mapScale * 100;
			imgLoader.loadClip(config.eimg, marker.imgClip);
		}
		//internal image
		else if (config.iimg)
		{
			marker.imgClip = marker.containerClip.attachMovie(config.iimg, "img", marker.containerClip.getNextHighestDepth());
			marker.imgClip._xscale = marker.imgClip._yscale = config.scale * mapScale * 100;
			marker.imgClip._x = -marker.imgClip._width / 2;
			marker.imgClip._y = -marker.imgClip._height / 2;
		}
		if (config.color1) CreateColor(marker, config);
		if (config.deathTooltip) CreateDeathMarker(marker, config);
		clearInterval(updateInterval);
		updateInterval = setInterval(Delegate.create(this, MoveMarkers), 50);
		MoveMarkers();
	}
	
	static function CreateColor(marker:MarkerObject, config:MarkerConfig)
	{
		if (config.color1 == config.color2 || !config.color2)
		{
			Colors.ApplyColor(marker.imgClip, config.color1);
		}
		else
		{
			if (marker.char.GetOffensiveTarget().IsPlayer())
			{
				Colors.ApplyColor(marker.imgClip, config.color2);
			}
			else
			{
				Colors.ApplyColor(marker.imgClip,  config.color1);
			}
			marker.slot = marker.char.SignalOffensiveTargetChanged.Connect(function()
			{
				if (!marker.char.GetOffensiveTarget().IsPlayer()) Colors.ApplyColor(marker.imgClip,  config.color1);
				else Colors.ApplyColor(marker.imgClip, config.color2);
			});
		}
	}
	
	static function CreateTimer(marker)
	{
		var f:Function = function()
		{
			var time =  Tracker.GetTimeString((new Date()).getTime(), marker.deathTime);
			
			if (marker.deathClip)
			{
				Tracker.HideOverlapping(marker);
				marker.deathClip.text = time;
			}
			var idx = _root.nametagcontroller.GetNametagIndex(marker.char.GetID());
			if (idx)
			{
				_root.nametagcontroller.m_NametagArray[idx].m_Name.text = marker.char.GetName() + " " + time
			}
			
		}
		marker.deathinterval = setInterval(f, 1000);
		f();
	}

	static function GetTimeString(end:Number, start:Number)
	{
		return com.Utils.Format.Printf( "%02.0f:%02.0f", Math.floor((end-start) / 60000), Math.round((end-start)  / 1000) % 60);
	}
	
	/* 
	* Checks supplied marker against all other markers, 
	* and hides it if there's overlapping older(but not if there's over 15s difference in the timer) marker at the location
	* displays the marker again if no overlapping markers is found
	*/
	static function HideOverlapping(marker:MarkerObject)
	{
		var found;
		for (var i in Tracker.markerArray)
		{
			var marker2:MarkerObject = Tracker.markerArray[i];
			if (marker != marker2 &&
				marker2.deathClip &&
				marker.containerClip.hitTest(marker2.containerClip) &&
				Math.abs(marker.deathTime - marker2.deathTime) < 15000 &&
				marker.deathTime > marker2.deathTime)
			{
				marker.deathClip._alpha = 0;
				found = true;
				if (marker2.containerClip.getDepth() < marker.containerClip.getDepth())
				{
					marker2.containerClip.swapDepths(marker.containerClip);
				}
				break;
			}
		}
		if (!found)
		{
			marker.deathClip._alpha = 100;
		}
	}
	
	static function CreateDeathMarker(marker:MarkerObject, config:MarkerConfig)
	{
		var f:Function = function()
		{
			if(!marker.deathTime && 
				(marker.char.m_InvisibleBuffList["9350410"] || marker.char.IsDead()))
			{
				marker.deathTime = (new Date()).getTime();
				marker.deathClip = marker.containerClip.createTextField("DeathClip", marker.containerClip.getNextHighestDepth(), 0, 0, 20, 20);
				var font:TextFormat = new TextFormat("_StandardFont", 12, 0xFFFFFF, true);
				marker.deathClip.setNewTextFormat(font);
				marker.deathClip.setTextFormat(font);
				marker.deathClip.background = true;
				marker.deathClip.backgroundColor = 0x000000;
				marker.deathClip.autoSize = true;
				marker.deathClip.text = "00:00";
				Tracker.CreateTimer(marker);
			}
		}
		marker.deathSlot = marker.char.SignalInvisibleBuffAdded.Connect(f);
		f();
	}

	public function MoveMarkers()
	{
		for (var i in markerArray)
		{
			var marker:MarkerObject = markerArray[i];
			//dead or playing dead
			if ((marker.char.IsDead() || marker.char.m_InvisibleBuffList["9350410"]) && !marker.config.keep)
			{
				ClearMarker(marker.char.GetID());
				continue;
			}
			var pos:Vector3 = marker.char.GetPosition();
			marker.containerClip._x = (pos.x - minX) * posToDist;
			marker.containerClip._y = (maxX - pos.z) * posToDist;
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
				marker.char.SignalInvisibleBuffAdded.DisconnectSlot(marker.deathSlot);
				clearInterval(marker.deathinterval);
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
			marker.char.SignalInvisibleBuffAdded.DisconnectSlot(marker.deathSlot);
			clearInterval(marker.deathinterval);
			marker.containerClip.removeMovieClip()
		}
		markerArray = new Array();
	}

}