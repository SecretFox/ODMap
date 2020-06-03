import com.GameInterface.Game.Character;
import com.Utils.Colors;
import com.Utils.Draw;
import com.Utils.ID32;
import com.fox.odmap.LegendEntry;
import com.fox.odmap.MarkerConfigLegend;
import com.fox.odmap.MarkerObject;
import com.fox.odmap.Tracker;
import mx.utils.Delegate;
/**
 * ...
 * @author fox
 */
class com.fox.odmap.Legend
{
	private var m_Map:MovieClip;
	private var LegendContent:MovieClip;
	private var m_BG:MovieClip;
	private var format:TextFormat;
	private var Entries:Array;
	private var updateInterval:Number;
	private var m_Tracker:Tracker;

	public function Legend(map, tracker:Tracker)
	{
		m_Map = map;
		m_Tracker = tracker;
		Entries = [];
		LegendContent = m_Map.createEmptyMovieClip("Legend", m_Map.getNextHighestDepth());
		m_BG = LegendContent.createEmptyMovieClip("BG", LegendContent.getNextHighestDepth());
		LegendContent._x = m_Map.Image._x;
		LegendContent._y =  m_Map.Image._y + m_Map.Image._height;
		format = new TextFormat("_StandardFont", 15, 0xFFFFFF, true);
	}

	public function Stop()
	{
		for (var i in Entries)
		{
			var Entry:LegendEntry = Entries[i];
			RemoveEntry(Entry.ID, true);
		}
		LegendContent.removeMovieClip();
		clearInterval(updateInterval);
	}

	public function Hide()
	{
		LegendContent._visible = false;
	}

	public function Unhide()
	{
		LegendContent._visible = true;
	}

	static function TestHunter(id:ID32,startTime:Number,expireTime:Number)
	{
		if (com.GameInterface.UtilsBase.GetNormalTime() * 1000 - startTime > 5000 && Character.GetCharacter(id).GetDistanceToPlayer() < 50) return true;
	}

	static function SliceName(name:String)
	{
		return name.split(" ").slice(2).join(" ");
	}

	public function AddEntry(marker:MarkerObject, id:ID32, time:Number, config:MarkerConfigLegend, expire:Boolean )
	{
		for (var i in Entries)
		{
			var Entry:LegendEntry = Entries[i];
			if (Entry.ID.toString() == id.toString())
			{
				if (config)
				{
					Entry.Config = config;
					Entry.Time = time;
					Entry.ExpireTime = expire;
					return
				}
				break;
			}
		}

		var Entry:LegendEntry = new LegendEntry();
		Entry.ID = id;
		Entry.Time = time;
		Entry.Config = config;
		Entry.ExpireTime = expire;

		Entry.TextRoot = LegendContent.createEmptyMovieClip(id.toString(), LegendContent.getNextHighestDepth());
		Entry.TextRoot._x = 5;
		var y = LegendEntry(Entries[Entries.length - 1]) ?
				(LegendEntry(Entries[Entries.length - 1]).TextRoot._y + LegendEntry(Entries[Entries.length - 1]).TextRoot._height) : 5;
		Entry.TextRoot._y =  y;

		Entry.TextRoot.onRollOver = function()
		{
			var highestClip:MarkerObject;
			for (var i in Tracker.markerArray)
			{
				var marker2:MarkerObject = Tracker.markerArray[i];
				if ((marker2.containerClip.getDepth() > highestClip.containerClip.getDepth() || !highestClip) &&
						marker2.config.depth == marker.config.depth &&
						marker2 != marker
				   )
				{
					highestClip = marker2;
				}
			}
			if (marker != highestClip) marker.containerClip.swapDepths(highestClip.containerClip);
			var f = function()
			{
				if (Entry.TextRoot.currentColor == 0xE80000)
				{
					Entry.TextRoot.currentColor = marker.currentColor;
					Colors.ApplyColor(marker.imgClip,  marker.currentColor);
				}
				else
				{
					Entry.TextRoot.currentColor = 0xE80000;
					Colors.ApplyColor(marker.imgClip, 0xE80000);
				}

			}
			Entry.TextRoot.interval = setInterval(f, 500);
			f();

		}

		Entry.TextRoot.onRollOut = function()
		{
			clearInterval(Entry.TextRoot.interval);
			Colors.ApplyColor(marker.imgClip, marker.currentColor);
			Entry.TextRoot.currentColor =  marker.currentColor;
		}

		var Text:TextField = Entry.TextRoot.createTextField("Left", Entry.TextRoot.getNextHighestDepth(), 0, 0, 0, 24);
		Text.setTextFormat(format);
		Text.setNewTextFormat(format);
		Text.text = SliceName(Character.GetCharacter(id).GetName());

		var Text2:TextField = Entry.TextRoot.createTextField("Right", Entry.TextRoot.getNextHighestDepth(), 0, 0,  m_Map.Image._width - 10, 24);
		Text2.setTextFormat(format);
		Text2.setNewTextFormat(format);
		Text2.text = "     ";
		Entries.push(Entry);
		UpdateBG();
		clearInterval(updateInterval);
		updateInterval = setInterval(Delegate.create(this, UpdateTimers), 500);
		UpdateTimers();
		UpdateWidth();
	}

	private function UpdateBG()
	{
		m_BG.clear();
		if (Entries.length > 0)
		{
			Draw.DrawRectangle(m_BG, 0, 0, m_Map.Image._width, LegendContent._height + 5, 0x000000, 80, [4, 4, 4, 4]);
		}
	}

	private function UpdateWidth()
	{
		for (var i in Entries)
		{
			var Entry:LegendEntry = Entries[i];
			Entry.TextRoot[LegendEntry.RightText]._width = Entry.TextRoot[LegendEntry.RightText].textWidth;
			Entry.TextRoot[LegendEntry.RightText]._x =  m_Map.Image._width - 15 - Entry.TextRoot[LegendEntry.RightText].textWidth;

			Entry.TextRoot[LegendEntry.LeftText]._width =  m_Map.Image._width - 15 - Entry.TextRoot[LegendEntry.RightText].textWidth;
		}
	}

	public function UpdatePosSize()
	{
		LegendContent._x = m_Map.Image._x;
		LegendContent._y =  m_Map.Image._y + m_Map.Image._height;
		for (var i in Entries)
		{
			//couldnt get it to line out properly by just updating width
			var Entry:LegendEntry = Entries[i];
			Entry.TextRoot[LegendEntry.RightText].removeTextField();
			var Text2:TextField = Entry.TextRoot.createTextField("Right", Entry.TextRoot.getNextHighestDepth(), 0, 0,  m_Map.Image._width - 10, 24);
			Text2.setTextFormat(format);
			Text2.setNewTextFormat(format);
		}
		UpdateTimers();
		UpdateBG();
		UpdateWidth();
	}

	public function RemoveEntry(id:ID32,force:Boolean)
	{
		// Remove Entry
		var found;
		for (var i in Entries)
		{
			var Entry:LegendEntry = Entries[i];
			if (Entry.ID.toString() == id.toString() && (!Entry.Config.force || force))
			{
				//Mod.ClearCachedLegend(id);
				Entry.TextRoot.removeMovieClip();
				Entries.splice(Number(i), 1);
				found = true;
				break;
			}
		}
		if (!found || force) return;

		// Reposition
		for (var i = 0; i < Entries.length; i++ )
		{
			var Entry:LegendEntry = Entries[i];
			Entry.TextRoot._y = i * Entry.TextRoot._height;
		}
		UpdateBG();
		if (Entries.length == 0)
		{
			clearInterval(updateInterval);
		}
	}

	public function UpdateTimers()
	{
		var GameTime:Number = com.GameInterface.UtilsBase.GetNormalTime() * 1000;
		for (var i in Entries)
		{
			var Entry:LegendEntry = Entries[i];
			if (Entry.Config.checkFunction)
			{
				if (Entry.Config.checkFunction(Entry.ID, Entry.Time))
				{
					Entry.Config.force = false;
					RemoveEntry(Entry.ID);
					continue;
				}
			}
			if (Entry.Config.direction == "down")
			{
				var timeLeft;
				if (!Entry.ExpireTime)
				{
					timeLeft = Entry.Config.duration * 1000 + GameTime - Entry.Time;
				}
				else
				{
					timeLeft = Entry.Config.duration * 1000 + Entry.Time - GameTime;
				}
				if (timeLeft < 0)
				{
					Entry.Config.force = false;
					RemoveEntry(Entry.ID);
					continue;
				}
				var time:Date = new Date(timeLeft);
				Entry.TextRoot[LegendEntry.RightText].text = com.Utils.Format.Printf("%02.0f:%02.0f", time.getUTCMinutes(), time.getUTCSeconds());
				for (var y in _root.nametagcontroller.m_NametagArray)
				{
					var m_Nametag/*:Nametag*/ = _root.nametagcontroller.m_NametagArray[y];
					if (m_Nametag["m_Character"].GetID().toString() == Entry.ID.toString())
					{
						m_Nametag["m_Name"].text = m_Nametag["m_Character"].GetName() + " " + Entry.TextRoot[LegendEntry.RightText].text;
					}
				}
				/* NOT RELIABLE FOR SOME REASON
				var idx = _root.nametagcontroller.GetNametagIndex(Entry.ID);
				if (idx)
				{
					_root.nametagcontroller.m_NametagArray[idx].m_Name.text = Entry.TextRoot[LegendEntry.LeftText].text + " " + Entry.TextRoot[LegendEntry.RightText].text;
				}
				*/
			}
			else if (Entry.Config.direction == "up")
			{
				var timeSpent = GameTime - Entry.Time;
				if (timeSpent > Entry.Config.duration * 1000 && Entry.Config.duration)
				{
					Entry.Config.force = false;
					RemoveEntry(Entry.ID);
					continue;
				}
				var time:Date = new Date(timeSpent);
				Entry.TextRoot[LegendEntry.RightText].text = com.Utils.Format.Printf("%02.0f:%02.0f", time.getUTCMinutes(), time.getUTCSeconds());
				for (var y in _root.nametagcontroller.m_NametagArray)
				{
					var m_Nametag/*:Nametag*/ = _root.nametagcontroller.m_NametagArray[y];
					if (m_Nametag["m_Character"].GetID().toString() == Entry.ID.toString())
					{
						m_Nametag["m_Name"].text = m_Nametag["m_Character"].GetName() + " " + Entry.TextRoot[LegendEntry.RightText].text;
					}
				}
			}
		}
	}

}