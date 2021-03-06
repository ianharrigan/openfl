package openfl._internal.renderer.dom;


import openfl._internal.renderer.canvas.CanvasGraphics;
import openfl.display.DisplayObject;
import openfl.geom.Matrix;

#if (js && html5)
import js.html.Element;
import js.Browser;
#end

@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)
@:access(openfl.geom.Matrix)


class DOMShape {
	
	
	public static inline function render (shape:DisplayObject, renderSession:RenderSession):Void {
		
		#if (js && html5)
		var graphics = shape.__graphics;
		
		if (shape.stage != null && shape.__worldVisible && shape.__renderable && graphics != null) {
			
			var useCanvas:Bool = DOMHelper.isComplexGraphics(shape);
			// use for testing for now
			useCanvas = true;
			var useDOM:Bool = true;
			
			if (graphics.__dirty || shape.__worldAlphaChanged) {
				if (useCanvas == true) {
					CanvasGraphics.render (graphics, renderSession);
					
					if (graphics.__canvas != null) {
						
						if (shape.__canvas == null) {
							
							shape.__canvas = cast Browser.document.createElement ("canvas");
							shape.__context = shape.__canvas.getContext ("2d");
							DOMRenderer.initializeElement (shape, shape.__canvas, renderSession);
							
						}
						
						shape.__canvas.width = graphics.__canvas.width;
						shape.__canvas.height = graphics.__canvas.height;
						
						shape.__context.globalAlpha = shape.__worldAlpha;
						shape.__context.drawImage (graphics.__canvas, 0, 0);
						
					} else {
						
						if (shape.__canvas != null) {
							
							renderSession.element.removeChild (shape.__canvas);
							shape.__canvas = null;
							shape.__style = null;
							
						}
						
					}
				}
				
				if (useDOM == true) { // should be else if - for testing for now
					if (shape.__element == null) {
						shape.__element = DOMHelper.createElement(shape);
					}
					
					DOMHelper.applyStyle(shape);
					
				}
				
			}
			
			if (shape.__canvas != null) {
				
				if (shape.__worldTransformChanged || graphics.__transformDirty) {
					
					graphics.__transformDirty = false;
					
					var transform = Matrix.__temp;
					transform.identity ();
					transform.translate (graphics.__bounds.x, graphics.__bounds.y);
					transform.concat (shape.__worldTransform);
					
					shape.__style.setProperty (renderSession.transformProperty, transform.to3DString (renderSession.roundPixels), null);
					
				}
				
				DOMRenderer.applyStyle (shape, renderSession, false, false, true);
				
			}
			
			/*
			if (graphics.__dirty || shape.__worldAlphaChanged || (shape.__canvas == null && graphics.__canvas != null)) {
				
				//#if old
				CanvasGraphics.render (graphics, renderSession);
				//#else
				//CanvasGraphics.renderObjectGraphics (shape, renderSession);
				//#end
				

				if (useCanvas == true) {
					if (graphics.__canvas != null) {
						
						if (shape.__canvas == null) {
							
							shape.__canvas = cast Browser.document.createElement ("canvas");
							shape.__context = shape.__canvas.getContext ("2d");
							DOMRenderer.initializeElement (shape, shape.__canvas, renderSession);
							
						}
						
						shape.__canvas.width = graphics.__canvas.width;
						shape.__canvas.height = graphics.__canvas.height;
						
						shape.__context.globalAlpha = shape.__worldAlpha;
						shape.__context.drawImage (graphics.__canvas, 0, 0);
						
					} else {
						
						if (shape.__canvas != null) {
							
							renderSession.element.removeChild (shape.__canvas);
							shape.__canvas = null;
							shape.__style = null;
							
						}
						
					}
				}
				
				// TODO: turn this off later if using canvas
				// DOM METHOD
				var el:Element = null;
				if (DOMElements.map.get(shape) == null) {
					el = DOMElements.createElement(shape);
				} else {
					DOMElements.applyStyle(shape);
				}
				DOMElements.renderGraphics(shape);
			}
			
			if (shape.__canvas != null) {
				
				if (shape.__worldTransformChanged || graphics.__transformDirty) {
					
					graphics.__transformDirty = false;
					
					var transform = Matrix.__temp;
					transform.identity ();
					transform.translate (graphics.__bounds.x, graphics.__bounds.y);
					transform.concat (shape.__worldTransform);
					
					shape.__style.setProperty (renderSession.transformProperty, transform.to3DString (renderSession.roundPixels), null);
					
				}
				
				DOMRenderer.applyStyle (shape, renderSession, false, false, true);
				
			}
			*/
			
		} else {
			
			if (shape.__canvas != null) {
				
				renderSession.element.removeChild (shape.__canvas);
				shape.__canvas = null;
				shape.__style = null;
				
			}
			
		}
		#end
		
	}
	
	
}