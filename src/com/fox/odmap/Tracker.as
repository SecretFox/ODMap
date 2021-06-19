import com.GameInterface.Chat;
import com.GameInterface.Game.Camera;
import com.GameInterface.Game.Character;
import com.GameInterface.Game.Team;
import com.GameInterface.Game.TeamInterface;
import com.GameInterface.MathLib.Vector3;
import com.GameInterface.Nametags;
import com.Utils.Colors;
import com.Utils.ID32;
import com.Utils.Signal;
import com.Utils.SignalGroup;
import com.fox.odmap.Legend;
import com.fox.odmap.MarkerConfig;
import com.fox.odmap.MarkerConfigLegend;
import com.fox.odmap.MarkerObject;
import com.fox.odmap.Mod;
import com.fox.odmap.SpawnConfig;
import com.fox.odmap.SpawnMarker;
import mx.utils.Delegate;
/*
* ...
* @author fox
*/
class com.fox.odmap.Tracker
{
	static var m_swfRoot:MovieClip;
	private var m_Player:Character;
	private var loadListener:Object;
	public var SignalLoadFailed:Signal;
	public var m_Legend:Legend;

	// Config
	private var trackerConfig:Array;
	private var XMLFile:XML;
	private var enableSpawns:Boolean;
	private var spawnConfig:SpawnConfig;
	private var MovingMap:Boolean;

	// Markers
	static var markerArray:Array;
	static var SpawnArray:Array;
	private var checkQueue:Array;
	private var checkTimeout:Number;

	static var minX:Number;
	static var maxX:Number;
	static var middleX:Number;
	static var LocToPix:Number;
	static var posToDist2:Number;
	static var mapScale:Number;
	static var portalLocations = [[235, 304], [214, 284], [205, 264], [212, 234], [231, 212], [264, 205], [282, 216], [298, 232], [307, 253], [303, 274], [286, 291], [264, 302]];

	// Stonehenge is perfectly centered circle,no need for Y
	//private var minY = 160;
	//private var maxY = 348;

	public function Tracker(root:MovieClip)
	{
		m_swfRoot = root;
		m_Legend = new Legend(root, this);
		m_Player = Character.GetClientCharacter();
		markerArray = [];
		trackerConfig = [];
		checkQueue = [];
		SpawnArray = [];
		loadListener = new Object();
		loadListener.onLoadComplete = Delegate.create(this,ImageLoaded);
		loadListener.onLoadError = Delegate.create(this,ImageFailed);
		SignalLoadFailed = new Signal();
		XMLFile = new XML();
		XMLFile.ignoreWhite = true;
		XMLFile.onLoad = Delegate.create(this, ProcessXML);
	}

	public function Hide()
	{
		m_swfRoot.onEnterFrame = undefined;
		MovingMap = true;
		for (var i in markerArray)MarkerObject(markerArray[i]).imgClip._visible = false;
		for (var i in SpawnArray) SpawnMarker(SpawnArray[i]).imgClip._visible = false;
		m_Legend.Hide();
	}

	public function Show()
	{
		m_swfRoot.onEnterFrame = Delegate.create(this, MoveMarkers);
		MovingMap = false;
		for (var i in markerArray) MarkerObject(markerArray[i]).imgClip._visible = true;
		for (var i in SpawnArray) SpawnMarker(SpawnArray[i]).imgClip._visible = true;
		m_Legend.Unhide();
	}

	public function Start()
	{
		XMLFile.load("ODMap/config.xml");
	}

	private function StartTracking()
	{
		MovingMap = false;
		AddToQueue(m_Player.GetID());
		var team:Team = TeamInterface.GetClientTeamInfo();
		for (var i in team.m_TeamMembers)
		{
			var teamMember = team.m_TeamMembers[i];
			AddToQueue(teamMember["m_CharacterId"]);
		}
		var legends:Array = Mod.GetCachedLegends();
		for (var i in legends)
		{
			var stringID:String = legends[i].split(",")[0];
			var splitID:Array = stringID.split(":");
			AddToQueue(new ID32(Number(splitID[0]), Number(splitID[1])));
		}
		Nametags.SignalNametagAdded.Connect(AddToQueue, this);
		Nametags.SignalNametagUpdated.Connect(AddToQueue, this);
		Nametags.SignalNametagRemoved.Connect(ClearMarker, this);
		Nametags.RefreshNametags();
	}

	public function Disconnect(keepLegends)
	{
		m_swfRoot.onEnterFrame = undefined;
		Nametags.SignalNametagAdded.Disconnect(AddToQueue, this);
		Nametags.SignalNametagUpdated.Disconnect(AddToQueue, this);
		Nametags.SignalNametagRemoved.Disconnect(ClearMarker, this);
		ClearMarkers(keepLegends);
		ClearSpawns();
		m_Legend.Stop();
		m_Legend = undefined;
		loadListener = undefined;
	}

	private function ProcessXML(success)
	{
		if (success)
		{
			var rootContent:XMLNode = XMLFile.firstChild;
			var markerContent:XMLNode = rootContent.firstChild;
			var spawnContent:XMLNode = rootContent.lastChild;
			var scaleMulti = Number(markerContent.attributes.scale) || 1;
			minX =  Number(markerContent.attributes.minX) || 160;
			maxX = Number(markerContent.attributes.maxX) || 348;
			middleX = (maxX + minX) / 2;
			for (var i = 0; i < markerContent.childNodes.length; i++ )
			{
				var filterNode:XMLNode = markerContent.childNodes[i];
				var config:MarkerConfig = new MarkerConfig();
				config.depth = Number(filterNode.attributes.depth | 0);
				config.scale = scaleMulti * Number(filterNode.attributes.scale) || 1 * scaleMulti;
				config.color1 = filterNode.attributes.color1;
				config.color2 = filterNode.attributes.color2;
				config.deadcolor = filterNode.attributes.deadcolor;
				config.rotate = filterNode.attributes.rotate == "true";
				config.keep = filterNode.attributes.keep == "true";
				config.aggroscale = Number(filterNode.attributes.aggroscale);
				var temp = filterNode.attributes.legend;
				if (temp)
				{
					var values = temp.split(",");
					var legend:MarkerConfigLegend = new MarkerConfigLegend();
					legend.id = values[0];
					legend.type = values[1];
					legend.duration = values[2];
					legend.direction = values[3];
					legend.force = values[4] == "true";
					legend.checkFunction = eval(values[5]);
					config.legend = legend;
				}
				config.identifier = filterNode.attributes.name+i;
				config.namefilter = filterNode.attributes.namefilter.toLowerCase().split(",");
				config.bufffilter = filterNode.attributes.bufffilter.split(",");
				config.iimg = filterNode.attributes.iimg;
				config.eimg = filterNode.attributes.eimg;
				trackerConfig.push(config);
			}
			enableSpawns = spawnContent.attributes.enabled == "true";
			if (enableSpawns)
			{
				spawnConfig = new SpawnConfig();
				spawnConfig.blacklist = string(spawnContent.attributes.blacklist).split(",");
				spawnConfig.snapToPortals = spawnContent.attributes.snapToPortals == "true";
				spawnConfig.duration = Number(spawnContent.attributes.duration);
				spawnConfig.enabled = spawnContent.attributes.enabled == "true";
				spawnConfig.minDistance = Number(spawnContent.attributes.minDistance);
				spawnConfig.depth = Number(spawnContent.attributes.depth);
				spawnConfig.scale = Number(spawnContent.attributes.scale);
				spawnConfig.opacity = Number(spawnContent.attributes.opacity);
				spawnConfig.iimg = spawnContent.attributes.iimg;
				spawnConfig.eimg = spawnContent.attributes.eimg;
			}
			
			for (var i in trackerConfig)
			{
				var conf:MarkerConfig = trackerConfig[i];
				var clip = m_swfRoot.getInstanceAtDepth(conf.depth); // allow several entries to use same depth
				if (!clip)
				{
					clip = m_swfRoot.createEmptyMovieClip(conf.identifier, conf.depth);
				}
				conf.targetClip = clip;
			}
			if (spawnConfig.enabled)
			{
				var clip = m_swfRoot.getInstanceAtDepth(spawnConfig.depth); // allow several entries to use same depth
				if (!clip)
				{
					spawnConfig.targetClip = m_swfRoot.createEmptyMovieClip("Spawns", spawnConfig.depth);
				}
			}
			CalculateLocToPixel();
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

	public function CalculateLocToPixel()
	{
		LocToPix = m_swfRoot.Image._width / (maxX - minX);
		for (var i in trackerConfig)
		{
			MarkerConfig(trackerConfig[i]).targetClip._x =  m_swfRoot.Image._x;
			MarkerConfig(trackerConfig[i]).targetClip._y =  m_swfRoot.Image._y;
		}
		if (enableSpawns)
		{
			spawnConfig.targetClip._x =  m_swfRoot.Image._x;
			spawnConfig.targetClip._y =  m_swfRoot.Image._y;
		}
	}

	public function ChangeScale()
	{
		mapScale = m_swfRoot.Image._width / 200;
		for (var i in markerArray)
		{
			var marker:MarkerObject = markerArray[i];
			marker.imgClip._xscale = marker.imgClip._yscale = marker.config.scale * mapScale * 100;
			marker.imgClip._x  = -marker.imgClip._width / 2;
			marker.imgClip._y = -marker.imgClip._height / 2;
		}
		for (var i in SpawnArray)
		{
			var marker:SpawnMarker = SpawnArray[i];
			marker.imgClip._xscale = marker.imgClip._yscale = spawnConfig.scale * mapScale * 100;
			marker.imgClip._x  = -marker.imgClip._width / 2;
			marker.imgClip._y = -marker.imgClip._height / 2;
			marker.containerClip._x = (marker.location.x - minX) * LocToPix;
			marker.containerClip._y = (maxX - marker.location.z) * LocToPix;
		}
	}

	private function AddToQueue(id:ID32)
	{
		checkQueue.push(id);
		clearTimeout(checkTimeout);
		checkTimeout = setTimeout(Delegate.create(this, CheckTag), 100);
	}

	private function AlreadyTracking(id:ID32)
	{
		for (var i in markerArray)
		{
			var marker:MarkerObject = markerArray[i];
			if (marker.char.GetID().Equal(id))
			{
				return true;
			}
		}
	}

	private function CheckTag()
	{
		while (checkQueue.length>0)
		{
			var id:ID32 = ID32(checkQueue.pop());
			var char:Character = Character.GetCharacter(id);
			if (!id.IsSimpleDynel() && !char.IsPet())
			{
				if (enableSpawns) CalculateSpawnLocation(char, id);
				if (!AlreadyTracking(id))
				{
					if (id.IsPlayer())
					{
						if char.IsClientChar() AddMarker(char, trackerConfig[0]);
						else AddMarker(char, trackerConfig[1]);
					}
					else
					{
						AddEnemyTag(char);
					}
				}
			}
		}
	}
	
	private function AddSpawn(char:Character, location:Vector3 )
	{
		var imgLoader:MovieClipLoader;
		var spawnMarker:SpawnMarker = new SpawnMarker();
		spawnMarker.containerClip = spawnConfig.targetClip.createEmptyMovieClip(char.GetID().toString(), spawnConfig.targetClip.getNextHighestDepth());
		spawnMarker.containerClip._visible = false;
		SpawnArray.push(spawnMarker);
		// external image
		if (spawnConfig.eimg)
		{
			imgLoader = new MovieClipLoader();
			imgLoader.addListener(loadListener);
			spawnMarker.imgClip = spawnMarker.containerClip.createEmptyMovieClip("img", spawnMarker.containerClip.getNextHighestDepth());
			spawnMarker.imgClip._xscale = spawnMarker.imgClip._yscale = spawnConfig.scale * mapScale * 100;
			imgLoader.loadClip(spawnConfig.eimg, spawnMarker.imgClip);
		}
		//internal image
		else if (spawnConfig.iimg)
		{
			spawnMarker.imgClip = spawnMarker.containerClip.attachMovie(spawnConfig.iimg, "img", spawnMarker.containerClip.getNextHighestDepth());
			spawnMarker.imgClip._xscale = spawnMarker.imgClip._yscale = spawnConfig.scale * mapScale * 100;
			spawnMarker.imgClip._x = -spawnMarker.imgClip._width / 2;
			spawnMarker.imgClip._y = -spawnMarker.imgClip._height / 2;
		}
		spawnMarker.location = location;
		spawnMarker.containerClip._x = (location.x - minX) * LocToPix;
		spawnMarker.containerClip._y = (maxX - location.z) * LocToPix;
		spawnMarker.containerClip._alpha = spawnConfig.opacity;
		// Remove markers that are outside the map
		if (!spawnMarker.imgClip.hitTest(m_swfRoot.Image))
		{
			for (var y in SpawnArray){
				if (SpawnArray[y] == spawnMarker)
				{
					SpawnArray.splice(Number(y), 1);
					spawnMarker.containerClip.removeMovieClip();
					return;
				}
			}
		}
		if (spawnConfig.snapToPortals)
		{
			var closeststDistance:Number = 999;
			var newLocation:Vector3 = new Vector3(location.x, location.y, location.z);
			for (var i in portalLocations)
			{
				var dist:Number = Math.sqrt(Math.pow(location.x - portalLocations[i][0], 2) + Math.pow(location.z - portalLocations[i][1], 2));
				if (dist < closeststDistance)
				{
					closeststDistance = dist;
					newLocation.x = portalLocations[i][0];
					newLocation.z = portalLocations[i][1];
				}
			}
			spawnMarker.containerClip._x = (newLocation.x - minX) * LocToPix;
			spawnMarker.containerClip._y = (maxX - newLocation.z) * LocToPix;
		}
		//Remove overlapping markers
		for (var i in SpawnArray){
			if (SpawnMarker(SpawnArray[i]) != spawnMarker && SpawnMarker(SpawnArray[i]).containerClip.hitTest(spawnMarker.containerClip)){
				for (var y in SpawnArray){
					if (SpawnArray[y] == spawnMarker)
					{
						SpawnArray.splice(Number(y), 1);
						spawnMarker.containerClip.removeMovieClip();
						return;
					}
				}
			}
		}
		//Marker is now ready to be shown
		spawnMarker.containerClip._visible = true;
		//Remove after X seconds
		setTimeout(Delegate.create(this, function(){
			for (var i in Tracker.SpawnArray){
				if (Tracker.SpawnArray[i] == spawnMarker)
				{
					Tracker.SpawnArray.splice(Number(i), 1);
					spawnMarker.containerClip.removeMovieClip();
				}
			}
		}), spawnConfig.duration * 1000);
	}
	
	private function CalculateSpawnLocation(char:Character, id:ID32)
	{
		if (!id.IsPlayer())
		{
			var pos:Vector3 = char.GetPosition();
			if (spawnConfig.minDistance)
			{
				if (Math.sqrt(Math.pow(pos.x - middleX, 2) + Math.pow(pos.z - middleX, 2)) < spawnConfig.minDistance)
				{
					return;
				}
				
			}
			if (spawnConfig.blacklist)
			{
				var mobName:String = char.GetName();
				for (var i in spawnConfig.blacklist)
				{
					if (mobName.indexOf(spawnConfig.blacklist[i]) >= 0)
					{
						return;
					}
				}
			}
			AddSpawn(char, pos);
		}
	}

	private function AddEnemyTag(char:Character)
	{
		var name:String = char.GetName().toLowerCase();
		for (var i = 2; i < trackerConfig.length; i++)
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

	private function ImageFailed(img:MovieClip)
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
		var imgLoader:MovieClipLoader;
		var marker:MarkerObject = new MarkerObject();
		if (char.IsClientChar()) marker.client = true;
		marker.char = char;
		marker.config = config;
		marker.m_Signals = new SignalGroup();
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
		if (config.legend) CreateLegend(marker, config, m_Legend, char);
		if (config.deadcolor) CreateDeadColor(marker, config, char);
		m_swfRoot.onEnterFrame = Delegate.create(this, MoveMarkers);
	}
	
	static function CreateDeadColor(marker, config, char)
	{
		if ((char.m_BuffList["9350410"] || char.m_InvisibleBuffList["9350410"]) && config.deadcolor)
		{
			Colors.ApplyColor(marker.imgClip, config.deadcolor);
			marker.char.SignalOffensiveTargetChanged.DisconnectSlot(marker.colorFunc);
		}
		var f:Function = function(buffID)
		{
			if (string(buffID) == "9350410")
			{
				Colors.ApplyColor(marker.imgClip, config.deadcolor);
				marker.char.SignalOffensiveTargetChanged.DisconnectSlot(marker.colorFunc);
			}
		}
		char.SignalBuffAdded.Connect(marker.m_Signals, f);
		char.SignalInvisibleBuffAdded.Connect(marker.m_Signals, f);
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
			var f:Function = function()
			{
				if (!marker.char.GetOffensiveTarget().IsPlayer())
				{
					Colors.ApplyColor(marker.imgClip,  config.color1);
				}
				else
				{
					Colors.ApplyColor(marker.imgClip, config.color2);
				}
			}
			marker.colorFunc = marker.char.SignalOffensiveTargetChanged.Connect(marker.m_Signals, f);
		}
	}

	static function CreateLegend(marker:MarkerObject, config:MarkerConfig, m_Legend:Legend, char:Character)
	{
		var Time2:Number = Mod.GetCachedLegend(char.GetID());
		if (Time2)
		{
			m_Legend.AddEntry(marker, char.GetID(), Time2, config.legend);
		}
		// Buff added
		if (config.legend.type == "abuff")
		{
			var f:Function = function(buffID)
			{
				if (string(buffID) == config.legend.id)
				{
					var Time:Number = com.GameInterface.UtilsBase.GetNormalTime() * 1000;
					if (config.legend.direction == "up" && config.legend.duration) Time += config.legend.duration * 1000;
					m_Legend.AddEntry(marker, char.GetID(), Time, config.legend);
					Mod.CacheLegend(char.GetID(), Time);
				}
			}
			char.SignalBuffAdded.Connect(marker.m_Signals, f);
			char.SignalInvisibleBuffAdded.Connect(marker.m_Signals, f);
			if (!m_Legend.HasLegend(char.GetID()))
			{
				if (char.m_BuffList[config.legend.id] || char.m_InvisibleBuffList[config.legend.id])
				{
					f(config.legend.id);
				}
			}
		}
		// Buff removed
		if (config.legend.type == "rbuff")
		{
			var f:Function = function(buffID)
			{
				if (string(buffID) == config.legend.id)
				{
					var Time:Number = com.GameInterface.UtilsBase.GetNormalTime() * 1000;
					if (config.legend.direction == "up" && config.legend.duration) Time += config.legend.duration * 1000;
					m_Legend.AddEntry(marker, char.GetID(), Time, config.legend);
					Mod.CacheLegend(char.GetID(), Time);
				}
			}
			char.SignalBuffRemoved.Connect(marker.m_Signals);
		}

		//Finished Cast
		if (config.legend.type == "fcast" ||
			config.legend.type == "scast")
		{
			var f = function()
			{
				marker.currentCast = arguments[0];
				if (arguments[0] == config.legend.id)
				{
					if (config.legend.type == "scast")
					{
						var Time:Number = com.GameInterface.UtilsBase.GetNormalTime() * 1000;
						if (config.legend.direction == "up" && config.legend.duration) Time += config.legend.duration * 1000;
						m_Legend.AddEntry(marker, char.GetID(), Time, config.legend);
						Mod.CacheLegend(char.GetID(), Time);
					}
				}
			}
			var f2 = function ()
			{
				marker.currentCast = undefined;
			}
			var f3 = function ()
			{
				if (marker.currentCast == config.legend.id && config.legend.type == "fcast")
				{
					var Time:Number = com.GameInterface.UtilsBase.GetNormalTime() * 1000;
					if (config.legend.direction == "up" && config.legend.duration) Time += config.legend.duration * 1000;
					m_Legend.AddEntry(marker, char.GetID(), Time, config.legend);
					Mod.CacheLegend(char.GetID(), Time);
				}
				marker.currentCast = undefined;
			}
			char.SignalCommandStarted.Connect(marker.m_Signals, f);
			char.SignalCommandAborted.Connect(marker.m_Signals, f2);
			char.SignalCommandEnded.Connect(marker.m_Signals, f3);
		}
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
			if (marker.config.aggroscale)
			{
				if (marker.char.GetOffensiveTarget().IsPlayer())
				{
					marker.imgClip._xscale = marker.imgClip._yscale = marker.config.aggroscale * mapScale * 100;
				}
				else
				{
					marker.imgClip._xscale = marker.imgClip._yscale = marker.config.scale * mapScale * 100;
				}
			}
			var pos:Vector3 = marker.char.GetPosition();
			marker.containerClip._x = (pos.x - minX) * LocToPix;
			marker.containerClip._y = (maxX - pos.z) * LocToPix;
			if (marker.config.rotate)
			{
				if (marker.client) marker.containerClip._rotation = -Camera.m_AngleY * 57.3;
				else marker.containerClip._rotation = -marker.char.GetRotation() * 57.3;
			}
			if marker.imgClip.hitTest(m_swfRoot.Image) marker.imgClip._visible = true;
			else marker.imgClip._visible = false;
		}
	}

	private function ClearMarker(id:ID32)
	{
		if ( id.IsPlayer()) return;
		for (var i in markerArray)
		{
			var marker:MarkerObject = markerArray[i];
			if (marker.char.GetID().Equal(id) && (marker.char.IsDead() || !marker.char.GetDistanceToPlayer()))
			{
				marker.m_Signals.DisconnectAll();
				marker.containerClip.removeMovieClip();
				m_Legend.RemoveEntry(marker.char.GetID());
				markerArray.splice(Number(i), 1);
				if (markerArray.length == 0)
				{
					m_swfRoot.onEnterFrame = undefined;
				}
				break
			}
		}
	}

	private function ClearMarkers(keepLegend:Boolean)
	{
		m_swfRoot.onEnterFrame = undefined;
		clearTimeout(checkTimeout);
		for (var i in markerArray)
		{
			var marker:MarkerObject = markerArray[i];
			marker.m_Signals.DisconnectAll();
			m_Legend.RemoveEntry(marker.char.GetID(), undefined, keepLegend);
			//marker.containerClip.removeMovieClip();
		}
		markerArray = [];
	}
	
	private function ClearSpawns()
	{
		SpawnArray = [];
	}

}