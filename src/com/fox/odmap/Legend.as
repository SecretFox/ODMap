import com.GameInterface.Game.Character;
import com.GameInterface.Game.CharacterBase;
import com.Utils.Draw;
import com.Utils.ID32;
import com.fox.odmap.LegendEntry;
import com.fox.odmap.MarkerConfigLegend;
import com.fox.odmap.MarkerObject;
import com.fox.odmap.Mod;
import com.fox.odmap.Tracker;
import mx.utils.Delegate;
/**
 * ...
 * @author fox
 */
class com.fox.odmap.Legend
{
	private var m_SwfRoot:MovieClip;
	private var LegendContent:MovieClip;
	private var m_BG:MovieClip;
	private var format:TextFormat;
	private var Entries:Array;
	private var updateInterval:Number;

	public function Legend(root:MovieClip)
	{
		m_SwfRoot = root;
		Entries = [];
		LegendContent = m_SwfRoot.createEmptyMovieClip("Legend", m_SwfRoot.getNextHighestDepth());
		m_BG = LegendContent.createEmptyMovieClip("BG", LegendContent.getNextHighestDepth());
		LegendContent._x = m_SwfRoot.Image._x;
		LegendContent._y =  m_SwfRoot.Image._y + m_SwfRoot.Image._height;
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

	static function TestHunter(id:ID32,time:Number)
	{
		if (com.GameInterface.UtilsBase.GetNormalTime() * 1000 - time > 5000 && Character.GetCharacter(id).GetDistanceToPlayer() < 50) return true;
	}

	static function SliceName(name:String)
	{
		return name.split(" ").slice(2).join(" ");
	}
	
	public function HasLegend(id:ID32)
	{
		for (var i in Entries)
		{
			if (LegendEntry(Entries[i]).ID.Equal(id)) return true;
		}
		return false;
	}

	public function AddEntry(marker:MarkerObject, id:ID32, Time:Number, config:MarkerConfigLegend)
	{
		for (var i in Entries)
		{
			if (Entries[i].ID.Equal(id))
			{
				LegendEntry(Entries[i]).Config.force = config.force;
				LegendEntry(Entries[i]).Time = Time;
				return;
			}
		}

		var Entry:LegendEntry = new LegendEntry();
		Entry.ID = id;
		Entry.Time = Time;
		Entry.Config = new MarkerConfigLegend();
		Entry.Config.checkFunction = config.checkFunction;
		Entry.Config.direction = config.direction;
		Entry.Config.duration = config.duration;
		Entry.Config.force = config.force;
		Entry.Config.id = config.id;
		Entry.Config.type = config.type;

		Entry.TextRoot = LegendContent.createEmptyMovieClip(id.toString(), LegendContent.getNextHighestDepth());
		Entry.TextRoot._x = 5;

		var f = function()
		{
			var highestClip:MarkerObject;
			for (var i in Tracker.markerArray)
			{
				var marker2:MarkerObject = Tracker.markerArray[i];
				if ((marker2.containerClip.getDepth() > highestClip.containerClip.getDepth() || !highestClip) &&
						marker2.config.depth == marker.config.depth &&
						marker2 != marker)
				{
					highestClip = marker2;
				}
			}
			if (marker != highestClip) marker.containerClip.swapDepths(highestClip.containerClip);
			marker.containerClip.arrow.removeMovieClip();
			var arrow:MovieClip = marker.containerClip.createEmptyMovieClip("arrow", marker.containerClip.getNextHighestDepth());
			arrow._x = marker.imgClip._x;
			arrow._y = marker.imgClip._y;
			arrow._xscale = arrow._yscale = 200;
			var width = marker.containerClip._width/4;
			arrow.lineStyle(1, 0xFFFFFF);
			arrow.beginFill(0x150700, 100);
			arrow.moveTo(width, 0);
			arrow.lineTo( width - 4, -3);
			
			arrow.lineTo( width-2, -3);
			arrow.lineTo( width-2, -10);
			arrow.lineTo(width+2, -10);
			arrow.lineTo(width+2, -3);
			arrow.lineTo(width+4, -3);
			arrow.lineTo(width, 0);
			arrow.endFill();
			CharacterBase.SignalCharacterEnteredReticuleMode.Connect(this.onRollOut, this);
		}

		var f2 = function()
		{
			marker.containerClip.arrow.removeMovieClip();
			CharacterBase.SignalCharacterEnteredReticuleMode.Disconnect(this.onRollOut, this);
		}
		Entry.TextRoot.onRollOver = f;
		Entry.TextRoot.onRollOut = f2;
		
		
		Entry.LeftText = Entry.TextRoot.createTextField("Left", Entry.TextRoot.getNextHighestDepth(), 0, 0, 0, 24);
		Entry.LeftText.setNewTextFormat(format);
		Entry.LeftText.text = SliceName(Character.GetCharacter(id).GetName());
		
		Entry.RightText = Entry.TextRoot.createTextField("Right", Entry.TextRoot.getNextHighestDepth(), 0, 0,  m_SwfRoot.Image._width - 10, 24);
		Entry.RightText.setNewTextFormat(format);
		Entry.RightText.text = "     ";
		Entries.push(Entry);
		
		clearInterval(updateInterval);
		updateInterval = setInterval(Delegate.create(this, UpdateTimers), 500);
		Entries.sort(Sorter)
		UpdateTimers();
		UpdateWidth();
		UpdateY();
		UpdateBG();
	}
	
	private function Sorter(a:LegendEntry,b:LegendEntry)
	{
		if (a.Config.direction == "up") return -1;
		if (a.Time < b.Time) return -1;
		return 1;
	}

	private function UpdateBG()
	{
		m_BG.clear();
		if (Entries.length > 0)
		{
			Draw.DrawRectangle(m_BG, 0, 0, m_SwfRoot.Image._width, LegendContent._height + 5, 0x000000, 80, [4, 4, 4, 4]);
		}
	}

	private function UpdateWidth()
	{
		for (var i in Entries)
		{
			var Entry:LegendEntry = Entries[i];
			Entry.RightText._width = Entry.RightText.textWidth;
			Entry.RightText._x =  m_SwfRoot.Image._width - 15 - Entry.RightText.textWidth;
			Entry.LeftText._width =  m_SwfRoot.Image._width - 15 - Entry.RightText.textWidth;
		}
	}
	
	public function UpdateY()
	{
		for (var i = 0; i < Entries.length; i++ )
		{
			var Entry:LegendEntry = Entries[i];
			Entry.TextRoot._y = 2 + i * Entry.TextRoot._height;
		}
	}
	
	public function UpdatePosSize()
	{
		LegendContent._x = m_SwfRoot.Image._x;
		LegendContent._y =  m_SwfRoot.Image._y + m_SwfRoot.Image._height;
		UpdateTimers();
		UpdateBG();
		UpdateWidth();
	}

	public function RemoveEntry(id:ID32, force:Boolean, keepLegend:Boolean)
	{
		var found;
		for (var i in Entries)
		{
			var Entry:LegendEntry = Entries[i];
			if (Entry.ID.Equal(id) && (!Entry.Config.force || force))
			{
				if(!keepLegend) Mod.ClearCachedLegend(id);
				Entry.TextRoot.removeMovieClip();
				Entries.splice(Number(i), 1);
				found = true;
				break;
			}
		}
		if (!found || force) return;

		UpdateY();
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
				var timeLeft = Entry.Config.duration * 1000 - (GameTime - Entry.Time);
				if (timeLeft < 0)
				{
					Entry.Config.force = false;
					RemoveEntry(Entry.ID);
					continue;
				}
				var time:Date = new Date(timeLeft);
				Entry.RightText.text = com.Utils.Format.Printf("%02.0f:%02.0f", time.getUTCMinutes(), time.getUTCSeconds());
				for (var y in _root.nametagcontroller.m_NametagArray)
				{
					var m_Nametag/*:Nametag*/ = _root.nametagcontroller.m_NametagArray[y];
					if (m_Nametag["m_Character"].GetID().Equal(Entry.ID))
					{
						m_Nametag["m_Name"].text = m_Nametag["m_Character"].GetName() + " " + Entry.RightText.text;
					}
				}
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
				Entry.RightText.text = com.Utils.Format.Printf("%02.0f:%02.0f", time.getUTCMinutes(), time.getUTCSeconds());
				for (var y in _root.nametagcontroller.m_NametagArray)
				{
					var m_Nametag/*:Nametag*/ = _root.nametagcontroller.m_NametagArray[y];
					if (m_Nametag["m_Character"].GetID().Equal(Entry.ID))
					{
						m_Nametag["m_Name"].text = m_Nametag["m_Character"].GetName() + " " + Entry.RightText.text;
					}
				}
			}
		}
	}

}