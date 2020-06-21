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
import com.fox.odmap.Legend;
import com.fox.odmap.MarkerConfig;
import com.fox.odmap.MarkerConfigLegend;
import com.fox.odmap.MarkerObject;
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

	// Markers
	static var markerArray:Array;
	private var updateInterval:Number;
	private var checkQueue:Array;
	private var checkTimeout;

	static var minX;
	static var maxX;
	static var LocToPix;
	static var posToDist2;
	static var mapScale;

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
		for (var i in markerArray) MarkerObject(markerArray[i]).imgClip._visible = false;
		m_Legend.Hide();
	}

	public function Show()
	{
		for (var i in markerArray) MarkerObject(markerArray[i]).imgClip._visible = true;
		m_Legend.Unhide();
	}

	public function Start()
	{
		XMLFile.load("ODMap/config.xml");
	}

	private function StartTracking()
	{
		AddToQueue(m_Player.GetID());
		var team:Team = TeamInterface.GetClientTeamInfo();
		for (var i in team.m_TeamMembers)
		{
			var teamMember = team.m_TeamMembers[i];
			AddToQueue(teamMember["m_CharacterId"]);
		}
		Nametags.SignalNametagAdded.Connect(AddToQueue, this);
		Nametags.SignalNametagUpdated.Connect(AddToQueue, this);
		Nametags.SignalNametagRemoved.Connect(ClearMarker, this);
		Nametags.RefreshNametags();
		/*VicinitySystem.SignalDynelEnterVicinity.Connect(EnteredVicinity, this);
		for (var i = 0; i < Dynel.s_DynelList.GetLength(); i++){
			var dynel:Dynel = Dynel.s_DynelList.GetObject(i);
			EnteredVicinity(dynel.GetID());
		}
		*/
	}

	public function Disconnect()
	{
		ClearMarkers();
		m_Legend.Stop();
		m_Legend = undefined;
		Nametags.SignalNametagAdded.Disconnect(AddToQueue, this);
		Nametags.SignalNametagUpdated.Disconnect(AddToQueue, this);
		Nametags.SignalNametagRemoved.Disconnect(ClearMarker, this);
		//VicinitySystem.SignalDynelEnterVicinity.Disconnect(EnteredVicinity, this);
		loadListener = undefined;
	}

	private function ProcessXML(success)
	{
		if (success)
		{
			var content:XMLNode = XMLFile.firstChild;
			var scaleMulti = Number(content.attributes.scale) || 1;
			minX =  Number(content.attributes.minX) || 160;
			maxX = Number(content.attributes.maxX) || 348;
			for (var i = 0; i < content.childNodes.length; i++ )
			{
				var filterNode:XMLNode = content.childNodes[i];
				var config:MarkerConfig = new MarkerConfig();
				config.depth = Number(filterNode.attributes.depth | 0);
				config.scale = scaleMulti * Number(filterNode.attributes.scale) || 1 * scaleMulti;
				config.color1 = filterNode.attributes.color1;
				config.color2 = filterNode.attributes.color2;
				config.rotate = filterNode.attributes.rotate == "true";
				config.keep = filterNode.attributes.keep == "true";
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
				config.namefilter = filterNode.attributes.namefilter.split(",");
				config.bufffilter = filterNode.attributes.bufffilter.split(",");
				config.iimg = filterNode.attributes.iimg;
				config.eimg = filterNode.attributes.eimg;
				trackerConfig.push(config);
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
			if (marker.char.GetID().toString() == id.toString())
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
			if (!AlreadyTracking(id))
			{
				var char:Character = Character.GetCharacter(id);
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
	
	
	/*
	//This succesfully finds the portal locations,but i found absolutely no way to tell whether they are activated,or when they activate
	private function EnteredVicinity(id:ID32)
	{
		if (id.IsSimpleDynel()){
			var keys:Array = [112, 12, 23, 1050];
			var dyn:Character = Dynel.GetDynel(id);
			if (dyn.GetStat(112, 2) == 8767301){
				var comp:Vector3 = new Vector3(255, 0, 255);
				var stats:Object = new Object();
				for (var i in keys)
				{
					stats[keys[i]] = dyn.GetStat(keys[i]);
					UtilsBase.PrintChatText("comp " + keys[i] + " = " + stats[keys[i]]);
				}
				VicinitySystem.SignalDynelEnterVicinity.Disconnect(EnteredVicinity, this);
				for (var i = -20; i < 20; i++){
					dyn = Dynel.GetDynel(new ID32(51320, id.GetInstance() - i));
					if (dyn.GetStat(112, 2) == 8767301){
						var distanceVector:Vector3 = Vector3.Sub(dyn.GetPosition(), comp);
						var distance = distanceVector.x + distanceVector.z;
						if (Math.abs(distance) > 10){
							AddMarker(dyn, trackerConfig[trackerConfig.length - 1]);
							dyn["_AddEffectPackage"] = dyn.AddEffectPackage;
							dyn.AddEffectPackage = function()
							{
								UtilsBase.PrintChatText(dyn.GetID().toString() +" called effect " + arguments+ " " +  dyn["_AddEffectPackage"]);
								return dyn["_AddEffectPackage"](arguments);
							}
							dyn.AddEffectPackage("test ");
							
							dyn["_AddLooksPackage"] = dyn.AddLooksPackage;
							dyn.AddLooksPackage = function()
							{
								UtilsBase.PrintChatText(dyn.GetID().toString() +" called lookspackage " + arguments+ " " +  dyn["_AddLooksPackage"]);
								return dyn["_AddLooksPackage"](arguments);
							}
							dyn.AddLooksPackage(0);
							for (var y in keys){
								if (stats[keys[y]] != dyn.GetStat(keys[y],2)) UtilsBase.PrintChatText(dyn.GetID() + " key " + keys[y] + " differs " + stats[keys[y]] + " vs " + dyn.GetStat(keys[y],2));
							}
							dyn.SignalBuffAdded.Connect(Delegate.create(this, function(){
								UtilsBase.PrintChatText(dyn.GetID().toString() +" added buff " + arguments);
							}));
								dyn.SignalInvisibleBuffAdded.Connect(Delegate.create(this, function(){
								UtilsBase.PrintChatText(dyn.GetID().toString() +" added invisible buff " + arguments);
							}));
								dyn.SignalInvisibleBuffUpdated.Connect(Delegate.create(this, function(){
								UtilsBase.PrintChatText(dyn.GetID().toString() +" uppdated invisible buff " + arguments);
							}));
							dyn.SignalInvisibleBuffUpdated.Connect(Delegate.create(this, function(){
								UtilsBase.PrintChatText(dyn.GetID().toString() +" updated buff " + arguments);
							}));
							dyn.SignalStatChanged.Connect(Delegate.create(this, function(){
								UtilsBase.PrintChatText(dyn.GetID().toString() +" changed stat " + arguments);
							}));
							dyn.SignalStateUpdated.Connect(Delegate.create(this, function(){
								UtilsBase.PrintChatText(dyn.GetID().toString() +" changed state " + arguments);
							}));
							dyn.SignalBuffRemoved.Connect(Delegate.create(this, function(){
								UtilsBase.PrintChatText(dyn.GetID().toString() +" removed buff " + arguments);
							}));
						}
					}
				}
			}
		}
	}
	*/
	
	private function AddEnemyTag(char:Character)
	{
		var name:String = char.GetName();
		if (name != "GHOST") // Invisible being inside the hag stone
		{
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
		if (config.legend) CreateLegend(marker, config, m_Legend);
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
			marker.char.SignalOffensiveTargetChanged.Connect(marker.m_Signals, f);
		}
	}

	static function CreateLegend(marker:MarkerObject, config:MarkerConfig, m_Legend:Legend)
	{
		// Buff added
		if (config.legend.type == "abuff")
		{
			var f:Function = function(buffID)
			{
				if (string(buffID) == config.legend.id)
				{
					var GameTime:Number = com.GameInterface.UtilsBase.GetNormalTime() * 1000;
					var time;
					var ExpireTime;
					if (marker.char.m_InvisibleBuffList[buffID])
					{
						time = marker.char.m_InvisibleBuffList[buffID].m_TotalTime;
					}
					else if (marker.char.m_BuffList[buffID])
					{
						time = marker.char.m_BuffList[buffID].m_TotalTime;
					}
					if (time <= GameTime)
					{
						ExpireTime = true;
					}
					m_Legend.AddEntry(marker, marker.char.GetID(), time, config.legend, ExpireTime);
					//Mod.CacheLegend(marker.char.GetID(), time);
				}
			}

			marker.char.SignalBuffAdded.Connect(marker.m_Signals, f);
			marker.char.SignalInvisibleBuffAdded.Connect(marker.m_Signals, f);
			if (marker.char.m_BuffList[config.legend.id])
			{
				f(config.legend.id);
			}
			if (marker.char.m_InvisibleBuffList[config.legend.id])
			{
				f(config.legend.id);
			}
		}

		// Buff removed
		if (config.legend.type == "rbuff")
		{
			var f:Function = function(buffID)
			{
				if (string(buffID) == config.legend.id)
				{
					var time:Number = com.GameInterface.UtilsBase.GetNormalTime()*1000;
					m_Legend.AddEntry(marker, marker.char.GetID(), time, config.legend);
					//Mod.CacheLegend(marker.char.GetID(), time);
				}
			}
			marker.char.SignalBuffRemoved.Connect(marker.m_Signals);
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
						var time:Number = com.GameInterface.UtilsBase.GetNormalTime() * 1000;
						m_Legend.AddEntry(marker, marker.char.GetID(), time, config.legend);
						//Mod.CacheLegend(marker.char.GetID(), time);
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
					var time:Number = com.GameInterface.UtilsBase.GetNormalTime() * 1000;
					m_Legend.AddEntry(marker, marker.char.GetID(), time, config.legend);
					//Mod.CacheLegend(marker.char.GetID(), time);
				}
				marker.currentCast = undefined;

			}
			marker.char.SignalCommandStarted.Connect(marker.m_Signals, f);
			marker.char.SignalCommandAborted.Connect(marker.m_Signals, f2);
			marker.char.SignalCommandEnded.Connect(marker.m_Signals, f3);

			/*
			var newchar:Character = Character.GetCharacter(marker.char.GetID());
			newchar.SignalBuffAdded.Connect(function(){
				UtilsBase.PrintChatText(newchar.GetName() +" added " + arguments);
				for (var i in newchar.m_BuffList){
					UtilsBase.PrintChatText("-" + i);
					for (var y in newchar.m_BuffList[i]){
						UtilsBase.PrintChatText("--" + y+" " + newchar.m_BuffList[i][y]);
					}
				}
			});
			newchar.SignalBuffRemoved.Connect(function(){
				UtilsBase.PrintChatText(newchar.GetName() +" removed " + arguments);
			});
			newchar.SignalInvisibleBuffAdded.Connect(function(){
				UtilsBase.PrintChatText(newchar.GetName() +" added invisible " + arguments);
				for (var i in newchar.m_InvisibleBuffList){
					UtilsBase.PrintChatText("-" + i);
					for (var y in newchar.m_InvisibleBuffList[i]){
						UtilsBase.PrintChatText("--" + y+" " + newchar.m_InvisibleBuffList[i][y]);
					}
				}
			});
			newchar.SignalBuffAdded.Emit();
			newchar.SignalInvisibleBuffAdded.Emit();
			newchar.SignalBuffRemoved.Emit();
			*/
		}
		/*
		var time:Number = Mod.GetCachedLegend(marker.char.GetID());
		if (time)
		{
			m_Legend.AddEntry(marker, marker.char.GetID(), time, config.legend);
		}
		*/
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
			if (marker.char.GetID().toString() == id.toString())
			{
				marker.m_Signals.DisconnectAll();
				marker.containerClip.removeMovieClip();
				m_Legend.RemoveEntry(marker.char.GetID());

				markerArray.splice(Number(i), 1);
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
			marker.m_Signals.DisconnectAll();
			m_Legend.RemoveEntry(marker.char.GetID());
			marker.containerClip.removeMovieClip()
		}
		markerArray = new Array();
	}

}