package flash.display;


import flash.accessibility.AccessibilityProperties;
import flash.display.BitmapData;
import flash.display.BlendMode;
import flash.display.DisplayObjectContainer;
import flash.display.Graphics;
import flash.display.IBitmapDrawable;
import flash.display.InteractiveObject;
import flash.display.Stage;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.EventPhase;
import flash.filters.BitmapFilter;
import flash.geom.ColorTransform;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.geom.Transform;
import flash.utils.Uuid;
import flash.Lib;
import js.html.CanvasElement;
import js.html.DivElement;
import js.html.Element;
import js.Browser;


class DisplayObject extends EventDispatcher implements IBitmapDrawable {
	
	
	private static inline var GRAPHICS_INVALID:Int = 1 << 1;
	private static inline var MATRIX_INVALID:Int = 1 << 2;
	private static inline var MATRIX_CHAIN_INVALID:Int = 1 << 3;
	private static inline var MATRIX_OVERRIDDEN:Int = 1 << 4;
	private static inline var TRANSFORM_INVALID:Int = 1 << 5;
	private static inline var BOUNDS_INVALID:Int = 1 << 6;
	private static inline var RENDER_VALIDATE_IN_PROGRESS:Int = 1 << 10;
	private static inline var ALL_RENDER_FLAGS:Int = GRAPHICS_INVALID | TRANSFORM_INVALID | BOUNDS_INVALID;
	
	public var accessibilityProperties:AccessibilityProperties;
	public var alpha:Float;
	public var blendMode:BlendMode;
	public var cacheAsBitmap:Bool;
	public var filters (get_filters, set_filters):Array<Dynamic>;
	public var height (get_height, set_height):Float;
	public var loaderInfo:LoaderInfo;
	public var mask (get_mask, set_mask):DisplayObject;
	public var mouseX (get_mouseX, never):Float;
	public var mouseY (get_mouseY, never):Float;
	public var name:String;
	public var parent (default, set_parent):DisplayObjectContainer;
	public var rotation (get_rotation, set_rotation):Float;
	public var scale9Grid:Rectangle;
	public var scaleX (get_scaleX, set_scaleX):Float;
	public var scaleY (get_scaleY, set_scaleY):Float;
	public var scrollRect (get_scrollRect, set_scrollRect):Rectangle;
	public var stage (get_stage, never):Stage;
	public var transform (default, set_transform):Transform;
	public var visible (get_visible, set_visible):Bool;
	public var width (get_width, set_width):Float;
	public var x (get_x, set_x):Float;
	public var y (get_y, set_y):Float;
	
	public var __combinedVisible (default, set___combinedVisible):Bool;
	
	private var __boundsRect:Rectangle;
	private var __filters:Array<BitmapFilter>;
	private var __height:Float;
	private var __mask:DisplayObject;
	private var __maskingObj:DisplayObject;
	private var __rotation:Float;
	private var __scaleX:Float;
	private var __scaleY:Float;
	private var __scrollRect:Rectangle;
	private var __visible:Bool;
	private var __width:Float;
	private var __x:Float;
	private var __y:Float;
	private var _bottommostSurface (get__bottommostSurface, null):Element;
	private var _boundsInvalid (get__boundsInvalid, never):Bool;
	private var _fullScaleX:Float;
	private var _fullScaleY:Float;
	private var _matrixChainInvalid (get__matrixChainInvalid, never):Bool;
	private var _matrixInvalid (get__matrixInvalid, never):Bool;
	private var ___id:String;
	private var ___renderFlags:Int;
	private var _topmostSurface (get__topmostSurface, null):Element;
	private var _srWindow : DivElement;
	private var _srAxes   : DivElement;

	
	public function new () {
		
		super (null);
		
		___id = Uuid.uuid ();
		parent = null;
		
		// initialize transform
		this.transform = new Transform (this);
		__x =  0.0;
		__y = 0.0;
		__scaleX = 1.0;
		__scaleY = 1.0;
		__rotation = 0.0;
		__width = 0.0;
		__height = 0.0;
		
		// initialize graphics metadata
		visible = true;
		alpha = 1.0;
		__filters = new Array<BitmapFilter> ();
		__boundsRect = new Rectangle ();
		
		__scrollRect = null;
		__mask = null;
		__maskingObj = null;
		__combinedVisible = visible;
		
	}
	
	
	public override function dispatchEvent (event:Event):Bool {
		
		var result = __dispatchEvent (event);
		
		if (event.__getIsCancelled ()) {
			
			return true;
			
		}
		
		if (event.bubbles && parent != null) {
			
			parent.dispatchEvent (event);
			
		}
		
		return result;
		
	}
	
	
	public function drawToSurface (inSurface:Dynamic, matrix:Matrix, inColorTransform:ColorTransform, blendMode:BlendMode, clipRect:Rectangle, smoothing:Bool):Void {
		
		var oldAlpha = alpha;
		alpha = 1;
		__render (inSurface, clipRect);
		alpha = oldAlpha;
		
	}
	
	
	public function getBounds (targetCoordinateSpace:DisplayObject):Rectangle {
		
		if (_matrixInvalid || _matrixChainInvalid) __validateMatrix ();
		if (_boundsInvalid) validateBounds ();
		
		var m = __getFullMatrix ();
		
		// perhaps inverse should be stored and updated lazily?
		if (targetCoordinateSpace != null) {
			
			// will be null when target space is stage and this is not on stage
			m.concat(targetCoordinateSpace.__getFullMatrix ().invert ());
			
		}
		
		var rect = __boundsRect.transform (m);	// transform does cloning
		return rect;
		
	}
	
	
	public function getRect (targetCoordinateSpace:DisplayObject):Rectangle {
		
		// should not account for stroke widths, but is that possible?
		return getBounds (targetCoordinateSpace);
		
	}
	
	
	private function getScreenBounds ():Rectangle {
		
		if (_boundsInvalid) validateBounds ();
		return __boundsRect.clone ();
		
	}
	
	
	private inline function getSurfaceTransform (gfx:Graphics):Matrix {
		
		var extent = gfx.__extentWithFilters;
		var fm = __getFullMatrix ();
		
		/*
		var tx = fm.tx;
		var ty = fm.ty;
		var nm = new Matrix();
		nm.scale(1/_fullScaleX, 1/_fullScaleY);
		fm = fm.mult(nm);
		fm.tx = tx;
		fm.ty = ty;
		*/
		
		fm.__translateTransformed (extent.topLeft);
		return fm;
		
	}
	
	
	public function globalToLocal (inPos:Point):Point {
		
		if (_matrixInvalid || _matrixChainInvalid) __validateMatrix ();
		return __getFullMatrix ().invert ().transformPoint (inPos);
		
	}
	
	
	private inline function handleGraphicsUpdated (gfx:Graphics):Void {
		
		__invalidateBounds ();
		__applyFilters (gfx.__surface);
		__setFlag (TRANSFORM_INVALID);
		
	}
	
	
	public function hitTestObject (obj:DisplayObject):Bool {
		
		if (obj != null && obj.parent != null && parent != null) {
			
			var currentBounds = getBounds (this);
			var targetBounds = obj.getBounds (this);
			
			return currentBounds.intersects (targetBounds);
			
		}
		
		return false;
		
	}
	
	
	public function hitTestPoint (x:Float, y:Float, shapeFlag:Bool = false):Bool {
		
		var boundingBox = (shapeFlag == null ? true : !shapeFlag);
		
		if (!boundingBox) {
			
			return __getObjectUnderPoint (new Point (x, y)) != null;
			
		} else {
			
			var gfx = __getGraphics ();
			
			if (gfx != null) {
				
				var extX = gfx.__extent.x;
				var extY = gfx.__extent.y;
				var local = globalToLocal (new Point (x, y));
				
				if (local.x - extX < 0 || local.y - extY < 0 || (local.x - extX) * scaleX > width || (local.y - extY) * scaleY > height) {
					
					return false;
					
				} else {
					
					return true;
					
				}
				
			}
			
			return false;
			
		}
		
	}
	
	
	private inline function invalidateGraphics ():Void {
		
		var gfx = __getGraphics ();
		if (gfx != null) gfx.__invalidate ();
		
	}
	
	
	public function localToGlobal (point:Point):Point {
		
		if (_matrixInvalid || _matrixChainInvalid) __validateMatrix ();
		return __getFullMatrix ().transformPoint (point);
		
	}
	
	
	private function setSurfaceVisible (inValue:Bool):Void {
		
		var gfx = __getGraphics ();
		
		if (gfx != null && gfx.__surface != null) {
			
			Lib.__setSurfaceVisible (gfx.__surface, inValue);
			
		}
		
	}
	
	
	override public function toString ():String {
		
		return "[DisplayObject name=" + this.name + " id=" + ___id + "]";
		
	}
	
	
	private function validateBounds ():Void {
		
		if (_boundsInvalid) {
			
			var gfx = __getGraphics ();
			
			if (gfx == null) {
				
				__boundsRect.x = x;
				__boundsRect.y = y;
				__boundsRect.width = 0;
				__boundsRect.height = 0;
				
			} else {
				
				__boundsRect = gfx.__extent.clone ();
				__setDimensions ();
				gfx.boundsDirty = false;
				
			}
			
			__clearFlag (BOUNDS_INVALID);
			
		}
		
	}
	
	
	private function __addToStage (newParent:DisplayObjectContainer, beforeSibling:DisplayObject = null):Void {
		
		var gfx = __getGraphics ();
		if (gfx == null) return;
		
		if (newParent.__getGraphics () != null) {
			
			Lib.__setSurfaceId (gfx.__surface, ___id);
			
			if (beforeSibling != null && beforeSibling.__getGraphics () != null) {
				
				Lib.__appendSurface (gfx.__surface, beforeSibling._bottommostSurface);
				
			} else {
				
				var stageChildren = [];
				
				for (child in newParent.__children) {
					
					if (child.stage != null) {
						
						stageChildren.push (child);
						
					}
					
				}
				
				if (stageChildren.length < 1) {
					
					Lib.__appendSurface (gfx.__surface, null, newParent._topmostSurface);
					
				} else {
					
					var nextSibling = stageChildren[stageChildren.length - 1];
					var container;
					
					while (Std.is (nextSibling, DisplayObjectContainer)) {
						
						container = cast (nextSibling, DisplayObjectContainer);
						
						if (container.numChildren > 0) {
							
							nextSibling = container.__children[container.numChildren - 1];
							
						} else {
							
							break;
							
						}
						
					}
					
					if (nextSibling.__getGraphics () != gfx) {
						
						Lib.__appendSurface (gfx.__surface, null, nextSibling._topmostSurface);
						
					} else {
						
						Lib.__appendSurface (gfx.__surface);
						
					}
					
				}
				
			}
			
			Lib.__setSurfaceTransform (gfx.__surface, getSurfaceTransform(gfx));
			
		} else {
			
			if (newParent.name == Stage.NAME) { // only stage is allowed to add to a parent with no context
				
				Lib.__appendSurface (gfx.__surface);
				
			}
			
		}
		
		if (__isOnStage ()) {
			this.__srUpdateDivs ();			
			var evt = new Event (Event.ADDED_TO_STAGE, false, false);
			dispatchEvent (evt);
			
		}
	}
	
	
	private inline function __applyFilters (surface:CanvasElement):Void {
		
		if (__filters != null) {
			
			for (filter in __filters) {
				
				filter.__applyFilter (surface);
				
			}
			
		} 
		
	}
	
	
	private function __broadcast (event:Event):Void {
		
		__dispatchEvent (event);
		
	}
	
	
	private inline function __clearFlag (mask:Int):Void {
		
		___renderFlags &= ~mask;
		
	}
	
	
	@:noCompletion public function __contains (child:DisplayObject):Bool {
		
		return false;
		
	}
	
	
	private function __dispatchEvent (event:Event):Bool {
		
		if (event.target == null) {
			
			event.target = this;
			
		}
		
		event.currentTarget = this;
		return super.dispatchEvent (event);
		
	}
	
	
	private function __fireEvent (event:Event):Void {
		
		var stack:Array<InteractiveObject> = [];
		
		if (this.parent != null) {
			
			this.parent.__getInteractiveObjectStack (stack);
			
		}
		
		var l = stack.length;
		
		if (l > 0) {
			
			// First, the "capture" phase ...
			event.__setPhase (EventPhase.CAPTURING_PHASE);
			stack.reverse ();
			
			for (obj in stack) {
				
				event.currentTarget = obj;
				obj.__dispatchEvent (event);
				
				if (event.__getIsCancelled ()) {
					
					return;
					
				}
				
			}
			
		}
		
		// Next, the "target"
		event.__setPhase (EventPhase.AT_TARGET);
		event.currentTarget = this;
		__dispatchEvent (event);
		
		if (event.__getIsCancelled ()) {
			
			return;
			
		}
		
		// Last, the "bubbles" phase
		if (event.bubbles) {
			
			event.__setPhase (EventPhase.BUBBLING_PHASE);
			stack.reverse ();
			
			for (obj in stack) {
				
				event.currentTarget = obj;
				obj.__dispatchEvent (event);
				
				if (event.__getIsCancelled ()) {
					
					return;
					
				}
				
			}
			
		}
		
	}
	
	
	public inline function __getFullMatrix (localMatrix:Matrix = null):Matrix {
		
		return transform.__getFullMatrix (localMatrix);
		
	}
	
	
	private function __getGraphics ():Graphics {
		
		return null;
		
	}
	
	
	private function __getInteractiveObjectStack (outStack:Array<InteractiveObject>):Void {
		
		var io:InteractiveObject = cast this;
		
		if (io != null) {
			
			outStack.push (io);
			
		}
		
		if (this.parent != null) {
			
			this.parent.__getInteractiveObjectStack (outStack);
			
		}
		
	}
	
	
	private inline function __getMatrix ():Matrix {
		
		return transform.matrix;
		
	}
	
	
	private function __getObjectUnderPoint (point:Point):DisplayObject {
		
		if (!visible) return null;
		var gfx = __getGraphics ();
		
		if (gfx != null) {
			
			gfx.__render ();
			
			var extX = gfx.__extent.x;
			var extY = gfx.__extent.y;
			var local = globalToLocal (point);
			
			if (local.x - extX <= 0 || local.y - extY <= 0 || (local.x - extX) * scaleX > width || (local.y - extY) * scaleY > height) return null;
			
			//switch (stage.__pointInPathMode) {
				//
				//case USER_SPACE:
					
					if (gfx.__hitTest (local.x, local.y)) {
						
						return cast this;
						
					}
				
				//case DEVICE_SPACE:
					//
					//if (gfx.__hitTest(local.x * scaleX, local.y * scaleY)) {
					//if (gfx.__hitTest(local.x, local.y)) {
						//
						//return cast this;
						//
					//}
				//
			//}
			
		}
		
		return null;
		
	}
	
	
	private inline function __getSurface ():CanvasElement {
		
		var gfx = __getGraphics ();
		var surface = null;
		
		if (gfx != null) {
			
			surface = gfx.__surface;
			
		}
		
		return surface;
		
	}
	
	
	private inline function __invalidateBounds ():Void {
		
		/**
		 * Bounds are invalidated when:
		 * - a child is added or removed from a container
		 * - a child is scaled, rotated, translated, or skewed
		 * - the display of an object changes(graphics changed,
		 * bitmap loaded, textbox resized)
		 * - a child has its bounds invalidated
		 * ---> Invalidates down to stage
		 */
		//** internal **//
		//** FINAL **//
		
		//TODO :: adjust so that parent is only invalidated if it's bounds are changed by this change
		
		__setFlag (BOUNDS_INVALID);
		
		if (parent != null) {
			
			parent.__setFlag (BOUNDS_INVALID);
			
		}
		
	}
	
	
	public function __invalidateMatrix (local:Bool = false):Void {
		
		/**
		 * Matrices are invalidated when:
		 * - the object is scaled, rotated, translated, or skewed
		 * - an object's parent has its matrices invalidated
		 * ---> 	Invalidates up through children
		 */
		
		if (local) {
			
			__setFlag (MATRIX_INVALID); // invalidate the local matrix
			
		} else {
			
			__setFlag (MATRIX_CHAIN_INVALID); // a parent has an invalid matrix
			
		}
		
	}
	
	
	private function __isOnStage ():Bool {
		
		var gfx = __getGraphics ();
		
		if (gfx != null && Lib.__isOnStage (gfx.__surface)) {
			
			return true;
			
		}
		
		return false;
		
	}
	
	
	public function __matrixOverridden ():Void {
		
		__x = transform.matrix.tx;
		__y = transform.matrix.ty;
		
		__setFlag (MATRIX_OVERRIDDEN);
		__setFlag (MATRIX_INVALID);
		__invalidateBounds ();
		
	}
	
	
	private function __removeFromStage ():Void {
		
		var gfx = __getGraphics ();
		
		if (gfx != null && Lib.__isOnStage (gfx.__surface)) {
			
			Lib.__removeSurface (gfx.__surface);
			var evt = new Event (Event.REMOVED_FROM_STAGE, false, false);
			evt.target = this;
			dispatchEvent (evt);
			
		}
		
	}
	
	
	private function __render (inMask:CanvasElement = null, clipRect:Rectangle = null) {
		
		if (!__combinedVisible) return;
		
		var gfx = __getGraphics ();
		if (gfx == null) return;
		
		if (_matrixInvalid || _matrixChainInvalid) __validateMatrix();
		
		/*
		var clip0:Point = null;
		var clip1:Point = null;
		var clip2:Point = null;
		var clip3:Point = null;
		if (clipRect != null) {
			var topLeft = clipRect.topLeft;
			var topRight = clipRect.topLeft.clone();
			topRight.x += clipRect.width;
			var bottomRight = clipRect.bottomRight;
			var bottomLeft = clipRect.bottomRight.clone();
			bottomLeft.x -= clipRect.width;
			clip0 = this.globalToLocal(this.parent.localToGlobal(topLeft));
			clip1 = this.globalToLocal(this.parent.localToGlobal(topRight));
			clip2 = this.globalToLocal(this.parent.localToGlobal(bottomRight));
			clip3 = this.globalToLocal(this.parent.localToGlobal(bottomLeft));
		}
		*/
		
		if (gfx.__render (inMask, __filters, 1, 1)) {
			
			handleGraphicsUpdated (gfx);
			
		}
		
		var fullAlpha:Float = (parent != null ? parent.__combinedAlpha : 1) * alpha;
		
		if (inMask != null) {
			
			var m = getSurfaceTransform (gfx);
			Lib.__drawToSurface (gfx.__surface, inMask, m, fullAlpha, clipRect);
			
		} else {
			
			if (__testFlag (TRANSFORM_INVALID)) {
				
				var m = getSurfaceTransform (gfx);
				Lib.__setSurfaceTransform (gfx.__surface, m);
				__clearFlag (TRANSFORM_INVALID);
				

				this.__srUpdateDivs ();
				// this.__updateParentNode();
			}
			
			Lib.__setSurfaceOpacity (gfx.__surface, fullAlpha);
			
			/*if (clipRect != null) {
				var rect = new Rectangle();
				rect.topLeft = this.globalToLocal(this.parent.localToGlobal(clipRect.topLeft));
				rect.bottomRight = this.globalToLocal(this.parent.localToGlobal(clipRect.bottomRight));
				Lib.__setSurfaceClipping(gfx.__surface, rect);
			}*/
			
		}

		// this.__updateParentNode();
		// if (this.__scrollRect == null) {
		// 	var pgfx = this.parent.__getGraphics();
		// 	if (pgfx != null && pgfx.__surface.parentNode != gfx.__surface.parentNode) {
		// 		pgfx.__surface.parentNode.appendChild(gfx.__surface);
		// 	}
		// }
		
	}
	
	
	private inline function __setDimensions ():Void {
		
		if (scale9Grid != null) {
			
			__boundsRect.width *= __scaleX;
			__boundsRect.height *= __scaleY;
			__width = __boundsRect.width;
			__height = __boundsRect.height;
			
		} else {
			
			__width = __boundsRect.width * __scaleX;
			__height = __boundsRect.height * __scaleY;
			
		}
		
	}
	
	
	private inline function __setFlag (mask:Int):Void {
		
		___renderFlags |= mask;
		
	}
	
	
	private inline function __setFlagToValue (mask:Int, value:Bool):Void {
		
		if (value) {
			
			___renderFlags |= mask;
			
		} else {
			
			___renderFlags &= ~mask;
			
		}
		
	}
	
	
	public inline function __setFullMatrix (inValue:Matrix):Matrix {
		
		return transform.__setFullMatrix (inValue);
		
	}
	
	
	private inline function __setMatrix (inValue:Matrix):Matrix {
		
		transform.__setMatrix (inValue);
		return inValue;
		
	}
	
	
	private inline function __testFlag (mask:Int):Bool {
		
		return (___renderFlags & mask) != 0;
		
	}
	
	
	private function __unifyChildrenWithDOM (lastMoveObj:DisplayObject = null) {
		
		var gfx = __getGraphics ();		

		if (gfx != null && lastMoveObj != null && this != lastMoveObj) {

			var ogfx = lastMoveObj.__getGraphics ();
			if (ogfx != null) {
				Lib.__setSurfaceZIndexAfter (
					(this.__scrollRect == null ? gfx.__surface : this._srWindow), 
					(
						lastMoveObj.__scrollRect == null
							? ogfx.__surface 
							: (
								lastMoveObj == this.parent
									? ogfx.__surface
									: lastMoveObj._srWindow
							)
					)
				);
			}
			
		}
		
		if (gfx == null) {
			
			return lastMoveObj;
			
		} else {
		
			return this;
		}
		
	}
	
	
	private function __validateMatrix ():Void {
		
		var parentMatrixInvalid = (_matrixChainInvalid && parent != null);
		
		if (_matrixInvalid || parentMatrixInvalid) {
			
			if (parentMatrixInvalid) parent.__validateMatrix (); // validate parent matrix
			var m = __getMatrix(); // validate local matrix
			
			if (__testFlag (MATRIX_OVERRIDDEN)) {
				
				__clearFlag (MATRIX_INVALID);
				
			}
			
			if (_matrixInvalid) {
				
				m.identity (); // update matrix if necessary
				m.scale (__scaleX, __scaleY); // set scale
			
				// set rotation if necessary
				var rad = __rotation * Transform.DEG_TO_RAD;
				if (rad != 0.0) {
					
					m.rotate (rad);
					
				}
				
				m.translate (__x, __y); // set translation
				__setMatrix (m);
				
			}
			
			var cm = __getFullMatrix ();
			var fm = (parent == null ? m : parent.__getFullMatrix (m));
			
			_fullScaleX = fm._sx;
			_fullScaleY = fm._sy;
			
			if (cm.a != fm.a || cm.b != fm.b || cm.c != fm.c || cm.d != fm.d || cm.tx != fm.tx || cm.ty != fm.ty) {
				
				__setFullMatrix (fm);
				__setFlag (TRANSFORM_INVALID);
				
			}
			
			__clearFlag (MATRIX_INVALID | MATRIX_CHAIN_INVALID | MATRIX_OVERRIDDEN);
			
		}
		
	}
	
	
	
	
	// Getters & Setters
	
	
	
	
	private function get__bottommostSurface ():Element {
		
		var gfx = __getGraphics ();
		if (gfx != null) return gfx.__surface;
		
		return null;
		
	}
	
	
	private function get_filters ():Array<BitmapFilter> {
		
		if (__filters == null) return [];
		var result = new Array<BitmapFilter> ();
		
		for (filter in __filters) {
			
			result.push (filter.clone ());
			
		}
		
		return result;
		
	}
	
	
	private inline function get__boundsInvalid ():Bool {
		
		var gfx = __getGraphics ();
		
		if (gfx == null) {
			
			return __testFlag (BOUNDS_INVALID);
			
		} else {
			
			return __testFlag (BOUNDS_INVALID) || gfx.boundsDirty;
			
		}
		
	}
	
	
	private function set_filters (filters:Array<Dynamic>):Array<Dynamic> {
		
		var oldFilterCount = (__filters == null) ? 0 : __filters.length;
		
		if (filters == null) {
			
			__filters = null;
			if (oldFilterCount > 0) invalidateGraphics ();
			
		} else {
			
			__filters = new Array<BitmapFilter> ();
			for (filter in filters) {
				if (filter != null) {
					__filters.push (filter.clone ());
				}
			}
			invalidateGraphics ();
			
		}
		
		return filters;
		
	}
	
	
	private function get_height ():Float {
		
		if (_boundsInvalid) {
			
			validateBounds ();
			
		}
		
		return __height;
		
	}
	
	
	private function set_height (inValue:Float):Float {
		
		if (_boundsInvalid) validateBounds ();
		var h = __boundsRect.height;
		
		if (__scaleY * h != inValue) {
			
			if (h == 0) {
				
				// patch to fix recovery from a height of zero
				
				__scaleY = 1;
				__invalidateMatrix (true);
				__invalidateBounds ();
				h = __boundsRect.height;
				
			}
			
			if (h <= 0) return 0;
			__scaleY = inValue / h;
			__invalidateMatrix (true);
			__invalidateBounds ();
			
		}
		
		return inValue;
		
	}
	
	
	private function get_mask ():DisplayObject {
		
		return __mask;
		
	}
	
	
	private function set_mask (inValue:DisplayObject):DisplayObject {
		
		if (__mask != null) {
			
			__mask.__maskingObj = null;
			
		}
		
		__mask = inValue;
		
		if (__mask != null) {
			
			__mask.__maskingObj = this;
			
		}
		
		return __mask;
		
	}
	
	
	private inline function get__matrixChainInvalid ():Bool {
		
		return __testFlag (MATRIX_CHAIN_INVALID);
		
	}
	
	
	private inline function get__matrixInvalid():Bool {
		
		return __testFlag (MATRIX_INVALID);
		
	}
	
	
	private function get_mouseX ():Float {
		
		return globalToLocal (new Point (stage.mouseX, 0)).x;
		
	}
	
	
	private function get_mouseY ():Float {
		
		return globalToLocal (new Point (0, stage.mouseY)).y;
		
	}
	
	
	private function set___combinedVisible (inValue:Bool):Bool {
		
		if (__combinedVisible != inValue) {
			
			__combinedVisible = inValue;
			setSurfaceVisible (inValue);
			
		}
		
		return __combinedVisible;
		
	}
	
	
	private function set_parent (inValue:DisplayObjectContainer):DisplayObjectContainer {
		
		if (inValue == this.parent) return inValue;
		__invalidateMatrix ();
		
		if (this.parent != null) {
			
			this.parent.__children.remove (this);
			this.parent.__invalidateBounds ();
			
		}
		
		if (inValue != null) {
			
			inValue.__invalidateBounds ();
			
		}
		
		if (this.parent == null && inValue != null) {
			
			this.parent = inValue;
			var evt = new Event (Event.ADDED, true, false);
			dispatchEvent(evt);
			
		} else if (this.parent != null && inValue == null) {
			
			this.parent = inValue;
			var evt = new Event (Event.REMOVED, true, false);
			dispatchEvent (evt);
			
		} else {
			
			this.parent = inValue;
			
		}
		
		return inValue;
		
	}
	
	
	private function get_rotation ():Float {
		
		return __rotation;
		
	}
	
	
	private function set_rotation (inValue:Float):Float {
		
		if (__rotation != inValue) {
			
			__rotation = inValue;
			__invalidateMatrix (true);
			__invalidateBounds ();
			
		}
		
		return inValue;
		
	}
	
	
	private function get_scaleX ():Float {
		
		return __scaleX;
		
	}
	
	
	private function set_scaleX (inValue:Float):Float {
		
		if (__scaleX != inValue) {
			
			__scaleX = inValue;
			__invalidateMatrix (true);
			__invalidateBounds ();
			
		}
		
		return inValue;
		
	}
	
	
	private function get_scaleY ():Float {
		
		return __scaleY;
		
	}
	
	
	private function set_scaleY (inValue:Float):Float {
		
		if (__scaleY != inValue) {
			
			__scaleY = inValue;
			__invalidateMatrix (true);
			__invalidateBounds ();
			
		}
		
		return inValue;
		
	}
	
	
	private function get_scrollRect ():Rectangle {
		
		if (__scrollRect == null) return null;
		return __scrollRect.clone ();
		
	}
	
	
	private function set_scrollRect (inValue:Rectangle):Rectangle {
		
		__scrollRect = inValue;
		this.__srUpdateDivs ();
		return inValue;
		
	}
	
	
	private function get_stage ():Stage {
		
		var gfx = __getGraphics ();
		
		if (gfx != null) {
			
			return Lib.__getStage ();
			
		}
		
		return null;
		
	}
	
	
	private function get__topmostSurface ():Element {
		
		var gfx = __getGraphics ();
		
		if (gfx != null) {
			
			return gfx.__surface;
			
		}
		
		return null;
		
	}
	
	
	private function set_transform (inValue:Transform):Transform {
		
		this.transform = inValue;
		__x = transform.matrix.tx;
		__y = transform.matrix.ty;
		__invalidateMatrix (true);
		return inValue;
		
	}
	
	
	private function get_visible ():Bool {
		
		return __visible;
		
	}
	
	
	private function set_visible (inValue:Bool):Bool {
		
		if (__visible != inValue) {
			
			__visible = inValue;
			setSurfaceVisible (inValue);
			
		}
		
		return __visible;
		
	}
	
	
	private function get_x ():Float {
		
		return __x;
		
	}
	
	
	private function set_x (inValue:Float):Float {
		
		if (__x != inValue) {
			
			__x = inValue;
			__invalidateMatrix (true);
			
			if (parent != null) {
				
				parent.__invalidateBounds ();
				
			}
			
		}
		
		return inValue;
		
	}
	
	
	private function get_y ():Float {
		
		return __y;
		
	}
	
	
	private function set_y (inValue:Float):Float {
		
		if (__y != inValue) {
			
			__y = inValue;
			__invalidateMatrix (true);
			
			if (parent != null) {
				
				parent.__invalidateBounds ();
				
			}
			
		}
		
		return inValue;
		
	}
	
	
	private function get_width ():Float {
		
		if (_boundsInvalid) {
			
			validateBounds ();
			
		}
		
		return __width;
		
	}
	
	
	private function set_width (inValue:Float):Float {
		
		if (_boundsInvalid) validateBounds ();
		var w = __boundsRect.width;
		
		if (__scaleX * w != inValue) {
			
			if (w == 0) {
				
				// patch to fix recovery from a width of zero
				
				__scaleX = 1;
				__invalidateMatrix (true);
				__invalidateBounds ();
				w = __boundsRect.width;
				
			}
			
			if (w <= 0) return 0;
			__scaleX = inValue / w;
			__invalidateMatrix (true);
			__invalidateBounds ();
			
		}
		
		return inValue;
		
	}
	
	
	public function __getSrWindow ():DivElement {
		
		return this._srWindow;
		
	}
	
	
	private function __srUpdateDivs ():Void {
		
		var gfx = __getGraphics ();
		if (gfx == null || parent == null) return;
		
		if (__scrollRect == null) {
			
			if (this._srAxes != null && gfx.__surface.parentNode == this._srAxes && this._srWindow.parentNode != null) {
				
				this._srWindow.parentNode.replaceChild (gfx.__surface, this._srWindow);
				
			}
			return;
			
		}
		
		if (this._srWindow == null) {
			
			this._srWindow = cast Browser.document.createElement ('div');
			this._srAxes = cast Browser.document.createElement ('div');
			
			this._srWindow.style.setProperty ("position", "absolute", "");
			this._srWindow.style.setProperty ("left", "0px", "");
			this._srWindow.style.setProperty ("top", "0px", "");
			this._srWindow.style.setProperty ("width", "0px", "");
			this._srWindow.style.setProperty ("height", "0px", "");
			this._srWindow.style.setProperty ("overflow", "hidden", "");
			
			this._srAxes.style.setProperty ("position", "absolute", "");
			this._srAxes.style.setProperty ("left", "0px", "");
			this._srAxes.style.setProperty ("top", "0px", "");
			
			this._srWindow.appendChild (this._srAxes);
			
		}

		var pnt = this.parent.localToGlobal (new Point (this.x, this.y));
		
		this._srWindow.style.left = pnt.x + "px";
		this._srWindow.style.top = pnt.y + "px";
		this._srWindow.style.width = __scrollRect.width + "px";
		this._srWindow.style.height = __scrollRect.height + "px";
		
		this._srAxes.style.left = (-pnt.x - __scrollRect.x) + "px";
		this._srAxes.style.top = (-pnt.y - __scrollRect.y) + "px";
		
		if (gfx.__surface.parentNode != this._srAxes && gfx.__surface.parentNode != null) {
			
			gfx.__surface.parentNode.insertBefore (this._srWindow, gfx.__surface);
			Lib.__removeSurface (gfx.__surface);
			this._srAxes.appendChild (gfx.__surface);
			
		}
		
	}
	
	
}