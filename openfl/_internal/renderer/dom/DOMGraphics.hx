package openfl._internal.renderer.dom;

import js.html.Element;
import openfl.display.DisplayObject;
import openfl.display.GradientType;

typedef GradientOptions = {
	@:optional var type:GradientType;
	@:optional var colors:Array<Dynamic>;
	@:optional var alphas:Array<Dynamic>;
	@:optional var ratios:Array<Dynamic>;
}

typedef BitmapOptions = {
	@:optional var base64:String;
	@:optional var width:Null<Int>;
	@:optional var height:Null<Int>;
}

typedef RadiusOptions = {
	@:optional var x:Null<Float>;
	@:optional var y:Null<Float>;
}

typedef StrokeOptions = {
	@:optional var thickness:Null<Float>;
	@:optional var color:Null<Int>;
	@:optional var alpha:Null<Float>;
	@:optional var gradient:GradientOptions;
	@:optional var bitmap:BitmapOptions;
}

typedef FillOptions = {
	@:optional var color:Null<Int>;
	@:optional var alpha:Null<Float>;
	@:optional var gradient:GradientOptions;
	@:optional var bitmap:BitmapOptions;
}

enum Primitive {
	RECTANGLE;
	CIRCLE;
	ELLIPSE;
}

typedef GraphicsOptions = {
	@:optional var x:Float;
	@:optional var y:Float;
	@:optional var w:Float;
	@:optional var h:Float;
	@:optional var primitive:Null<Primitive>;
	@:optional var radius:RadiusOptions;
	@:optional var stroke:StrokeOptions;
	@:optional var fill:FillOptions;
}

@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)
@:access(openfl._internal.renderer.dom.DOMElement)
class DOMGraphics {
	public function new() {
		
	}
	
	public function render(shape:DisplayObject) {
		var domElement:DOMElement = shape.__element;
		if (domElement == null) {
			return;
		}
		
		var el:Element = domElement._el;
		if (el == null) {
			return;
		}
		
		while (el.firstChild != null) { // remove all children (how does "graphics.clear" work??")
			el.removeChild(el.firstChild);
		}

		var data = new DrawCommandReader(shape.__graphics.__commands);
		var options:GraphicsOptions  = { };
		
		for (type in shape.__graphics.__commands.types) {
			switch (type) {
				case LINE_STYLE:
					var c = data.readLineStyle();
					if (options.stroke == null) options.stroke = { };
					
					options.stroke.thickness = c.thickness;
					options.stroke.color = c.color;
					options.stroke.alpha = c.alpha;
					
				case LINE_GRADIENT_STYLE:	
					var c = data.readLineGradientStyle();
					if (options.stroke == null) options.stroke = { };
					options.stroke.gradient = { };
					
					options.stroke.gradient.type = c.type;
					options.stroke.gradient.colors = c.colors;
					options.stroke.gradient.alphas = c.alphas;
					options.stroke.gradient.ratios = c.ratios;
					
				case LINE_BITMAP_STYLE:
					var c = data.readLineBitmapStyle();
					if (options.stroke == null) options.stroke = { };
					options.stroke.bitmap = { };
					
					options.stroke.bitmap.base64 = DOMHelper.getImageBase64(c.bitmap);
					options.stroke.bitmap.width = c.bitmap.width;
					options.stroke.bitmap.height = c.bitmap.height;
					
				case DRAW_RECT:
					var c = data.readDrawRect();
					options.primitive = Primitive.RECTANGLE;
					options.x = c.x;
					options.y = c.y;
					options.w = c.width;
					options.h = c.height;
				
				case DRAW_ROUND_RECT:
					var c = data.readDrawRoundRect();
					options.primitive = Primitive.RECTANGLE;
					options.x = c.x;
					options.y = c.y;
					options.w = c.width;
					options.h = c.height;
					options.radius = { x: c.rx, y: c.ry };
					
				case DRAW_CIRCLE:	
					var c = data.readDrawCircle();
					options.primitive = Primitive.CIRCLE;
					options.x = c.x;
					options.y = c.y;
					options.w = c.radius * 2;
					options.h = c.radius * 2;
					
				case DRAW_ELLIPSE:	
					var c = data.readDrawEllipse();
					options.primitive = Primitive.ELLIPSE;
					options.x = c.x;
					options.y = c.y;
					options.w = c.width;
					options.h = c.height;
					
				case BEGIN_FILL:
					var c = data.readBeginFill();
					if (options.fill == null) options.fill = { };
					
					options.fill.color = c.color;
					options.fill.alpha = c.alpha;
					
				case BEGIN_GRADIENT_FILL:
					var c = data.readLineGradientStyle();
					if (options.fill == null) options.fill = { };
					options.fill.gradient = { };
					
					options.fill.gradient.type = c.type;
					options.fill.gradient.colors = c.colors;
					options.fill.gradient.alphas = c.alphas;
					options.fill.gradient.ratios = c.ratios;
					
				case BEGIN_BITMAP_FILL:	
					var c = data.readLineBitmapStyle();
					if (options.fill == null) options.fill = { };
					options.fill.bitmap = { };

					options.fill.bitmap.base64 = DOMHelper.getImageBase64(c.bitmap);
					options.fill.bitmap.width = c.bitmap.width;
					options.fill.bitmap.height = c.bitmap.height;
					
				case END_FILL:
					if (options.primitive != null) {
						var g:DOMGraphic = new DOMGraphic(el);
						g.render(options);
					}
					
					options = { };
					
				default:
					data.skip(type);
			}
		}
	}
}