package openfl._internal.renderer.cairo;


import lime.graphics.cairo.Cairo;
import lime.graphics.cairo.CairoExtend;
import lime.graphics.cairo.CairoImageSurface;
import lime.graphics.cairo.CairoPattern;
import lime.graphics.cairo.CairoSurface;
import lime.math.Matrix3;
import lime.math.Vector2;
import openfl._internal.renderer.RenderSession;
import openfl.display.BitmapData;
import openfl.display.CapsStyle;
import openfl.display.DisplayObject;
import openfl._internal.renderer.DrawCommandBuffer;
import openfl._internal.renderer.DrawCommandReader;
import openfl._internal.renderer.DrawCommandType;
import openfl.display.GradientType;
import openfl.display.Graphics;
import openfl.display.InterpolationMethod;
import openfl.display.SpreadMethod;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.Lib;
import openfl.Vector;

@:access(openfl.display.DisplayObject)
@:access(openfl.display.BitmapData)
@:access(openfl.display.Graphics)
@:access(openfl.display.Tilesheet)
@:access(openfl.geom.Matrix)


class CairoGraphics {
	
	
	private static var SIN45 = 0.70710678118654752440084436210485;
	private static var TAN22 = 0.4142135623730950488016887242097;
	
	private static var bitmapFill:BitmapData;
	private static var bitmapRepeat:Bool;
	private static var bounds:Rectangle;
	private static var cairo:Cairo;
	private static var fillCommands:DrawCommandBuffer = new DrawCommandBuffer();
	private static var fillPattern:CairoPattern;
	private static var fillPatternMatrix:Matrix;
	private static var graphics:Graphics;
	private static var hasFill:Bool;
	private static var hasStroke:Bool;
	private static var hitTesting:Bool;
	private static var inversePendingMatrix:Matrix;
	private static var pendingMatrix:Matrix;
	private static var strokeCommands:DrawCommandBuffer = new DrawCommandBuffer();
	private static var strokePattern:CairoPattern;
	
	
	private static function closePath ():Void {
		
		if (strokePattern == null) {
			
			return;
			
		}
		
		cairo.closePath ();
		cairo.source = strokePattern;
		if (!hitTesting) cairo.strokePreserve ();
		cairo.newPath ();
		
	}
	
	
	private static function createGradientPattern (type:GradientType, colors:Array<Dynamic>, alphas:Array<Dynamic>, ratios:Array<Dynamic>, matrix:Matrix, spreadMethod:Null<SpreadMethod>, interpolationMethod:Null<InterpolationMethod>, focalPointRatio:Null<Float>):CairoPattern {
		
		var pattern:CairoPattern = null;
		
		switch (type) {
			
			case RADIAL:
				
				if (matrix == null) matrix = new Matrix ();
				
				var point = matrix.transformPoint (new Point (1638.4, 0));
				
				var x = matrix.tx + graphics.__bounds.x;
				var y = matrix.ty + graphics.__bounds.y;
				
				pattern = CairoPattern.createRadial (x, y, 0, x, y, (point.x - matrix.tx) / 2);
			
			case LINEAR:
				
				if (matrix == null) matrix = new Matrix ();
				
				var point1 = matrix.transformPoint (new Point (-819.2, 0));
				var point2 = matrix.transformPoint (new Point (819.2, 0));
				
				point1.x += graphics.__bounds.x;
				point2.x += graphics.__bounds.x;
				point1.y += graphics.__bounds.y;
				point2.y += graphics.__bounds.y;
				
				pattern = CairoPattern.createLinear (point1.x, point1.y, point2.x, point2.y);
			
		}
		
		for (i in 0...colors.length) {
			
			var rgb = colors[i];
			var alpha = alphas[i];
			var r = ((rgb & 0xFF0000) >>> 16) / 0xFF;
			var g = ((rgb & 0x00FF00) >>> 8) / 0xFF;
			var b = (rgb & 0x0000FF) / 0xFF;
			
			var ratio = ratios[i] / 0xFF;
			if (ratio < 0) ratio = 0;
			if (ratio > 1) ratio = 1;
			
			pattern.addColorStopRGBA (ratio, r, g, b, alpha);
			
		}
		
		var mat = pattern.matrix;
		
		mat.tx = bounds.x; 
		mat.ty = bounds.y; 
		
		pattern.matrix = mat;
		
		return pattern;
		
	}
	
	
	private static function createImagePattern (bitmapFill:BitmapData, matrix:Matrix, bitmapRepeat:Bool):CairoPattern {
		
		var pattern = CairoPattern.createForSurface (bitmapFill.getSurface ());
		
		if (bitmapRepeat) {
			
			pattern.extend = CairoExtend.REPEAT;
			
		}
		
		fillPatternMatrix = matrix;
		
		return pattern;
		
	}
	
	
	private static function drawRoundRect (x:Float, y:Float, width:Float, height:Float, rx:Float, ry:Float):Void {
		
		if (ry == -1) ry = rx;
		
		rx *= 0.5;
		ry *= 0.5;
		
		if (rx > width / 2) rx = width / 2;
		if (ry > height / 2) ry = height / 2;
		
		var xe = x + width,
		ye = y + height,
		cx1 = -rx + (rx * SIN45),
		cx2 = -rx + (rx * TAN22),
		cy1 = -ry + (ry * SIN45),
		cy2 = -ry + (ry * TAN22);
		
		cairo.moveTo (xe, ye - ry);
		quadraticCurveTo (xe, ye + cy2, xe + cx1, ye + cy1);
		quadraticCurveTo (xe + cx2, ye, xe - rx, ye);
		cairo.lineTo (x + rx, ye);
		quadraticCurveTo (x - cx2, ye, x - cx1, ye + cy1);
		quadraticCurveTo (x, ye + cy2, x, ye - ry);
		cairo.lineTo (x, y + ry);
		quadraticCurveTo (x, y - cy2, x - cx1, y - cy1);
		quadraticCurveTo (x - cx2, y, x + rx, y);
		cairo.lineTo (xe - rx, y);
		quadraticCurveTo (xe + cx2, y, xe + cx1, y - cy1);
		quadraticCurveTo (xe, y - cy2, xe, y + ry);
		cairo.lineTo (xe, ye - ry);
		
	}
	
	
	private static function endFill ():Void {
		
		cairo.newPath ();
		playCommands (fillCommands, false);
		fillCommands.clear();
		
	}
	
	
	private static function endStroke ():Void {
		
		cairo.newPath ();
		playCommands (strokeCommands, true);
		cairo.closePath ();
		strokeCommands.clear();
		
	}
	
	
	public static function hitTest (graphics:Graphics, x:Float, y:Float):Bool {
		
		#if lime_cairo
		CairoGraphics.graphics = graphics;
		bounds = graphics.__bounds;
		
		if (graphics.__commands.length == 0 || bounds == null || bounds.width == 0 || bounds.height == 0 || !bounds.contains (x, y)) {
			
			return false;
			
		} else {
			
			hitTesting = true;
			
			x -= bounds.x;
			y -= bounds.y;
			
			if (graphics.__cairo == null) {
				
				var bitmap = new BitmapData (Math.floor (bounds.width), Math.floor (bounds.height), true);
				var surface = bitmap.getSurface ();
				graphics.__cairo = new Cairo (surface);
				surface.destroy ();
				
				graphics.__bitmap = bitmap;
				
			}
			
			cairo = graphics.__cairo;
			
			fillCommands.clear ();
			strokeCommands.clear ();
			
			hasFill = false;
			hasStroke = false;
			
			fillPattern = null;
			strokePattern = null;
			
			cairo.newPath ();
			
			var data = new DrawCommandReader (graphics.__commands);
			
			for (type in graphics.__commands.types) {
				
				switch (type) {
					
					case CUBIC_CURVE_TO:
						
						var c = data.readCubicCurveTo ();
						fillCommands.cubicCurveTo (c.controlX1, c.controlY1, c.controlX2, c.controlY2, c.anchorX, c.anchorY);
						strokeCommands.cubicCurveTo (c.controlX1, c.controlY1, c.controlX2, c.controlY2, c.anchorX, c.anchorY);
					
					case CURVE_TO:
						
						var c = data.readCurveTo ();
						fillCommands.curveTo (c.controlX, c.controlY, c.anchorX, c.anchorY);
						strokeCommands.curveTo (c.controlX, c.controlY, c.anchorX, c.anchorY);
					
					case LINE_TO:
						
						var c = data.readLineTo ();
						fillCommands.lineTo (c.x, c.y);
						strokeCommands.lineTo (c.x, c.y);
					
					case MOVE_TO:
						
						var c = data.readMoveTo ();
						fillCommands.moveTo (c.x, c.y);
						strokeCommands.moveTo (c.x, c.y);
					
					case LINE_STYLE:
						
						var c = data.readLineStyle ();
						strokeCommands.lineStyle (c.thickness, c.color, c.alpha, c.pixelHinting, c.scaleMode, c.caps, c.joints, c.miterLimit);
					
					case LINE_GRADIENT_STYLE:
						
						var c = data.readLineGradientStyle ();
						strokeCommands.lineGradientStyle (c.type, c.colors, c.alphas, c.ratios, c.matrix, c.spreadMethod, c.interpolationMethod, c.focalPointRatio);
					
					case LINE_BITMAP_STYLE:
						
						var c = data.readLineBitmapStyle ();
						strokeCommands.lineBitmapStyle (c.bitmap, c.matrix, c.repeat, c.smooth);
					
					case END_FILL:
						
						data.readEndFill ();
						endFill ();
						endStroke ();
						
						if (hasFill && cairo.inFill (x, y)) {
							
							data.destroy ();
							return true;
							
						}
						
						if (hasStroke && cairo.inStroke (x, y)) {
							
							data.destroy ();
							return true;
							
						}
						
						hasFill = false;
						bitmapFill = null;
					
					case BEGIN_BITMAP_FILL, BEGIN_FILL, BEGIN_GRADIENT_FILL:
						
						endFill ();
						endStroke ();
						
						if (hasFill && cairo.inFill (x, y)) {
							
							data.destroy ();
							return true;
							
						}
						
						if (hasStroke && cairo.inStroke (x, y)) {
							
							data.destroy ();
							return true;
							
						}
						
						if (type == BEGIN_BITMAP_FILL) {
							
							var c = data.readBeginBitmapFill ();
							fillCommands.beginBitmapFill (c.bitmap, c.matrix, c.repeat, c.smooth);
							strokeCommands.beginBitmapFill (c.bitmap, c.matrix, c.repeat, c.smooth);
							
						} else if (type == BEGIN_GRADIENT_FILL) {
							
							var c = data.readBeginGradientFill ();
							fillCommands.beginGradientFill (c.type, c.colors, c.alphas, c.ratios, c.matrix, c.spreadMethod, c.interpolationMethod, c.focalPointRatio);
							strokeCommands.beginGradientFill (c.type, c.colors, c.alphas, c.ratios, c.matrix, c.spreadMethod, c.interpolationMethod, c.focalPointRatio);
							
						} else {
							
							var c = data.readBeginFill ();
							fillCommands.beginFill (c.color, c.alpha);
							strokeCommands.beginFill (c.color, c.alpha);
							
						}
					
					case DRAW_CIRCLE:
						
						var c = data.readDrawCircle ();
						fillCommands.drawCircle (c.x, c.y, c.radius);
						strokeCommands.drawCircle (c.x, c.y, c.radius);
					
					case DRAW_ELLIPSE:
						
						var c = data.readDrawEllipse ();
						fillCommands.drawEllipse (c.x, c.y, c.width, c.height);
						strokeCommands.drawEllipse (c.x, c.y, c.width, c.height);
					
					case DRAW_RECT:
						
						var c = data.readDrawRect ();
						fillCommands.drawRect (c.x, c.y, c.width, c.height);
						strokeCommands.drawRect (c.x, c.y, c.width, c.height);
					
					case DRAW_ROUND_RECT:
						
						var c = data.readDrawRoundRect ();
						fillCommands.drawRoundRect (c.x, c.y, c.width, c.height, c.rx, c.ry);
						strokeCommands.drawRoundRect (c.x, c.y, c.width, c.height, c.rx, c.ry);
					
					default:
						
						data.skip (type);
					
				}
				
			}
			
			if (fillCommands.length > 0) {
				
				endFill ();
				
			}
			
			if (strokeCommands.length > 0) {
				
				endStroke ();
				
			}
			
			data.destroy ();
			
			if (hasFill && cairo.inFill (x, y)) {
				
				return true;
				
			}
			
			if (hasStroke && cairo.inStroke (x, y)) {
				
				return true;
				
			}
			
		}
		#end
		
		return false;
		
	}
	
	
	private static inline function isCCW (x1:Float, y1:Float, x2:Float, y2:Float, x3:Float, y3:Float) {
		
		return ((x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1)) < 0;
		
	}
	
	
	private static function normalizeUVT (uvt:Vector<Float>, skipT:Bool = false):{ max:Float, uvt:Vector<Float> } {
		
		var max:Float = Math.NEGATIVE_INFINITY;
		var tmp = Math.NEGATIVE_INFINITY;
		var len = uvt.length;
		
		for (t in 1...len + 1) {
			
			if (skipT && t % 3 == 0) {
				
				continue;
				
			}
			
			tmp = uvt[t - 1];
			
			if (max < tmp) {
				
				max = tmp;
				
			}
			
		}
		
		var result = new Vector<Float> ();
		
		for (t in 1...len + 1) {
			
			if (skipT && t % 3 == 0) {
				
				continue;
				
			}
			
			result.push ((uvt[t - 1] / max));
			
		}
		
		return { max: max, uvt: result };
		
	}
	
	
	private static function playCommands (commands:DrawCommandBuffer, stroke:Bool = false):Void {
		
		if (commands.length == 0) return;
		
		bounds = graphics.__bounds;
		
		var offsetX = bounds.x;
		var offsetY = bounds.y;
		
		var positionX = 0.0;
		var positionY = 0.0;
		
		var closeGap = false;
		var startX = 0.0;
		var startY = 0.0;
		
		cairo.fillRule = EVEN_ODD;
		cairo.antialias = SUBPIXEL;
		
		var hasPath:Bool = false;
		
		var data = new DrawCommandReader (commands);
		
		for (type in commands.types) {
			
			switch (type) {
				
				case CUBIC_CURVE_TO:
					
					var c = data.readCubicCurveTo ();
					hasPath = true;
					cairo.curveTo (c.controlX1 - offsetX, c.controlY1 - offsetY, c.controlX2 - offsetX, c.controlY2 - offsetY, c.anchorX - offsetX, c.anchorY - offsetY);
				
				case CURVE_TO:
					
					var c = data.readCurveTo ();
					hasPath = true;
					quadraticCurveTo (c.controlX - offsetX, c.controlY - offsetY, c.anchorX - offsetX, c.anchorY - offsetY);
				
				case DRAW_CIRCLE:
					
					var c = data.readDrawCircle ();
					hasPath = true;
					cairo.moveTo (c.x - offsetX + c.radius, c.y - offsetY);
					cairo.arc (c.x - offsetX, c.y - offsetY, c.radius, 0, Math.PI * 2);
				
				case DRAW_RECT:
				
					var c = data.readDrawRect ();
					hasPath = true;
					cairo.rectangle (c.x - offsetX, c.y - offsetY, c.width, c.height);
				
				case DRAW_ELLIPSE:
					
					var c = data.readDrawEllipse ();
					hasPath = true;
					
					var x = c.x;
					var y = c.y;
					var width = c.width;
					var height = c.height;
					
					x -= offsetX;
					y -= offsetY;
					
					var kappa = .5522848,
						ox = (width / 2) * kappa, // control point offset horizontal
						oy = (height / 2) * kappa, // control point offset vertical
						xe = x + width,           // x-end
						ye = y + height,           // y-end
						xm = x + width / 2,       // x-middle
						ym = y + height / 2;       // y-middle
					
					cairo.moveTo (x, ym);
					cairo.curveTo (x, ym - oy, xm - ox, y, xm, y);
					cairo.curveTo (xm + ox, y, xe, ym - oy, xe, ym);
					cairo.curveTo (xe, ym + oy, xm + ox, ye, xm, ye);
					cairo.curveTo (xm - ox, ye, x, ym + oy, x, ym);
				
				case DRAW_ROUND_RECT:
					
					var c = data.readDrawRoundRect ();
					hasPath = true;
					drawRoundRect (c.x - offsetX, c.y - offsetY, c.width, c.height, c.rx, c.ry);
				
				case LINE_TO:
					
					var c = data.readLineTo ();
					hasPath = true;
					cairo.lineTo (c.x - offsetX, c.y - offsetY);
					
					positionX = c.x;
					positionY = c.y;
				
				case MOVE_TO:
					
					var c = data.readMoveTo ();
					cairo.moveTo (c.x - offsetX, c.y - offsetY);
					
					positionX = c.x;
					positionY = c.y;
					
					closeGap = true;
					startX = c.x;
					startY = c.y;
				
				case LINE_STYLE:
					
					var c = data.readLineStyle ();
					if (stroke && hasStroke) {
						
						closePath ();
						
					}
					
					cairo.moveTo (positionX - offsetX, positionY - offsetY);
					
					if (c.thickness == null) {
						
						hasStroke = false;
						
					} else {
						
						hasStroke = true;
						
						cairo.lineWidth = (c.thickness > 0 ? c.thickness : 1);
						
						if (c.joints == null) {
							
							cairo.lineJoin = ROUND;
							
						} else {
							
							cairo.lineJoin = switch (c.joints) {
								
								case MITER: MITER;
								case BEVEL: BEVEL;
								default: ROUND;
								
							}
							
						}
						
						if (c.caps == null) {
							
							cairo.lineCap = ROUND;
							
						} else {
							
							cairo.lineCap = switch (c.caps) {
								
								case NONE: BUTT;
								case SQUARE: SQUARE;
								default: ROUND;
								
							}
							
						}
						
						cairo.miterLimit = (c.miterLimit == null ? 3 : c.miterLimit);
						
						if (c.color != null) {
							
							var r = ((c.color & 0xFF0000) >>> 16) / 0xFF;
							var g = ((c.color & 0x00FF00) >>> 8) / 0xFF;
							var b = (c.color & 0x0000FF) / 0xFF;
							
							if (strokePattern != null) {
								
								strokePattern.destroy ();
								
							}
							
							if (c.alpha == 1 || c.alpha == null) {
								
								strokePattern = CairoPattern.createRGB (r, g, b);
								
							} else {
								
								strokePattern = CairoPattern.createRGBA (r, g, b, c.alpha);
								
							}
							
						}
						
					}
				
				case LINE_GRADIENT_STYLE:
					
					var c = data.readLineGradientStyle ();
					if (stroke && hasStroke) {
						
						closePath ();
						
					}
					
					if (strokePattern != null) {
						
						strokePattern.destroy ();
						
					}
					
					cairo.moveTo (positionX - offsetX, positionY - offsetY);
					strokePattern = createGradientPattern (c.type, c.colors, c.alphas, c.ratios, c.matrix, c.spreadMethod, c.interpolationMethod, c.focalPointRatio);
					
					hasStroke = true;
				
				case LINE_BITMAP_STYLE:
					
					var c = data.readLineBitmapStyle ();
					if (stroke && hasStroke) {
						
						closePath ();
						
					}
					
					if (strokePattern != null) {
						
						strokePattern.destroy ();
						
					}
					
					cairo.moveTo (positionX - offsetX, positionY - offsetY);
					strokePattern = createImagePattern (c.bitmap, c.matrix, c.repeat);
					
					hasStroke = true;
				
				case BEGIN_BITMAP_FILL:
					
					var c = data.readBeginBitmapFill ();
					if (fillPattern != null) {
						
						fillPattern.destroy ();
						
					}
					
					fillPattern = createImagePattern (c.bitmap, c.matrix, c.repeat);
					
					bitmapFill = c.bitmap;
					bitmapRepeat = c.repeat;
					
					hasFill = true;
				
				case BEGIN_FILL:
					
					var c = data.readBeginFill ();
					if (c.alpha < 0.005) {
						
						hasFill = false;
						
					} else {
						
						if (fillPattern != null) {
							
							fillPattern.destroy ();
							fillPatternMatrix = null;
							
						}
						
						fillPattern = CairoPattern.createRGBA (((c.color & 0xFF0000) >>> 16) / 0xFF, ((c.color & 0x00FF00) >>> 8) / 0xFF, (c.color & 0x0000FF) / 0xFF, c.alpha);
						hasFill = true;
						
					}
					
					bitmapFill = null;
				
				case BEGIN_GRADIENT_FILL:
					
					var c = data.readBeginGradientFill ();
					if (fillPattern != null) {
						
						fillPattern.destroy ();
						fillPatternMatrix = null;
						
					}
					
					fillPattern = createGradientPattern (c.type, c.colors, c.alphas, c.ratios, c.matrix, c.spreadMethod, c.interpolationMethod, c.focalPointRatio);
					
					hasFill = true;
					bitmapFill = null;
				
				case DRAW_TRIANGLES:
					
					var c = data.readDrawTriangles ();
					var v = c.vertices;
					var ind = c.indices;
					var uvt:Vector<Float> = c.uvtData;
					var colorFill = bitmapFill == null;
					
					if (colorFill && uvt != null) {
						
						break;
						
					}
					
					var width = 0;
					var height = 0;
					
					if (!colorFill) {
						
						//TODO move this to Graphics?
						
						if (uvt == null) {
							
							uvt = new Vector<Float> ();
							
							for (i in 0...(Std.int (v.length / 2))) {
								
								uvt.push (v[i * 2] / bitmapFill.width);
								uvt.push (v[i * 2 + 1] / bitmapFill.height);
								
							}
							
						}
						
						var skipT = c.uvtData.length != v.length;
						var normalizedUVT = normalizeUVT (uvt, skipT);
						var maxUVT = normalizedUVT.max;
						uvt = normalizedUVT.uvt;
						
						if (maxUVT > 1) {
							width = Std.int (bounds.width);
							height = Std.int (bounds.height);
							
							
						} else {
							
							width = bitmapFill.width;
							height = bitmapFill.height;
							
						}
						
					}
					
					var i = 0;
					var l = ind.length;
					
					var a_:Int, b_:Int, c_:Int;
					var iax:Int, iay:Int, ibx:Int, iby:Int, icx:Int, icy:Int;
					var x1:Float, y1:Float, x2:Float, y2:Float, x3:Float, y3:Float;
					var uvx1:Float, uvy1:Float, uvx2:Float, uvy2:Float, uvx3:Float, uvy3:Float;
					var denom:Float;
					var t1:Float, t2:Float, t3:Float, t4:Float;
					var dx:Float, dy:Float;
					
					cairo.antialias = NONE;
					
					while (i < l) {
						
						a_ = i;
						b_ = i + 1;
						c_ = i + 2;
						
						iax = ind[a_] * 2;
						iay = ind[a_] * 2 + 1;
						ibx = ind[b_] * 2;
						iby = ind[b_] * 2 + 1;
						icx = ind[c_] * 2;
						icy = ind[c_] * 2 + 1;
						
						x1 = v[iax];
						y1 = v[iay];
						x2 = v[ibx];
						y2 = v[iby];
						x3 = v[icx];
						y3 = v[icy];
						
						switch (c.culling) {
							
							case POSITIVE:
								
								if (!isCCW (x1, y1, x2, y2, x3, y3)) {
									
									i += 3;
									continue;
									
								}
							
							case NEGATIVE:
								
								if (isCCW (x1, y1, x2, y2, x3, y3)) {
									
									i += 3;
									continue;
									
								}
							
							default:
								
						}
						
						if (colorFill) {
							
							cairo.newPath ();
							cairo.moveTo (x1, y1);
							cairo.lineTo (x2, y2);
							cairo.lineTo (x3, y3);
							cairo.closePath ();
							if (!hitTesting) cairo.fillPreserve ();
							i += 3;
							continue;
							
						} 
						
						cairo.identityMatrix();
						//cairo.resetClip();
						
						cairo.newPath ();
						cairo.moveTo (x1, y1);
						cairo.lineTo (x2, y2);
						cairo.lineTo (x3, y3);
						cairo.closePath ();
						//cairo.clip ();
						
						uvx1 = uvt[iax] * width;
						uvx2 = uvt[ibx] * width;
						uvx3 = uvt[icx] * width;
						uvy1 = uvt[iay] * height;
						uvy2 = uvt[iby] * height;
						uvy3 = uvt[icy] * height;
						
						denom = uvx1 * (uvy3 - uvy2) - uvx2 * uvy3 + uvx3 * uvy2 + (uvx2 - uvx3) * uvy1;
						
						if (denom == 0) {
							
							i += 3;
							continue;
							
						}
						
						t1 = - (uvy1 * (x3 - x2) - uvy2 * x3 + uvy3 * x2 + (uvy2 - uvy3) * x1) / denom;
						t2 = (uvy2 * y3 + uvy1 * (y2 - y3) - uvy3 * y2 + (uvy3 - uvy2) * y1) / denom;
						t3 = (uvx1 * (x3 - x2) - uvx2 * x3 + uvx3 * x2 + (uvx2 - uvx3) * x1) / denom;
						t4 = - (uvx2 * y3 + uvx1 * (y2 - y3) - uvx3 * y2 + (uvx3 - uvx2) * y1) / denom;
						dx = (uvx1 * (uvy3 * x2 - uvy2 * x3) + uvy1 * (uvx2 * x3 - uvx3 * x2) + (uvx3 * uvy2 - uvx2 * uvy3) * x1) / denom;
						dy = (uvx1 * (uvy3 * y2 - uvy2 * y3) + uvy1 * (uvx2 * y3 - uvx3 * y2) + (uvx3 * uvy2 - uvx2 * uvy3) * y1) / denom;
						
						var matrix = new Matrix3 (t1, t2, t3, t4, dx, dy);
						cairo.matrix = matrix;
						cairo.source = fillPattern;
						if (!hitTesting) cairo.fill ();
						
						i += 3;
						
					}
				
				case DRAW_TILES:
					
					var c = data.readDrawTiles ();
					var useScale = (c.flags & Graphics.TILE_SCALE) > 0;
					var useRotation = (c.flags & Graphics.TILE_ROTATION) > 0;
					var offsetX = bounds.x;
					var offsetY = bounds.y;
					
					var useTransform = (c.flags & Graphics.TILE_TRANS_2x2) > 0;
					var useRGB = (c.flags & Graphics.TILE_RGB) > 0;
					var useAlpha = (c.flags & Graphics.TILE_ALPHA) > 0;
					var useRect = (c.flags & Graphics.TILE_RECT) > 0;
					var useOrigin = (c.flags & Graphics.TILE_ORIGIN) > 0;
					var useBlendAdd = (c.flags & Graphics.TILE_BLEND_ADD) > 0;
					var useBlendOverlay = (c.flags & Graphics.TILE_BLEND_OVERLAY) > 0;
					
					if (useTransform) { useScale = false; useRotation = false; }
					
					var scaleIndex = 0;
					var rotationIndex = 0;
					var rgbIndex = 0;
					var alphaIndex = 0;
					var transformIndex = 0;
					
					var numValues = 3;
					
					if (useRect) { numValues = useOrigin ? 8 : 6; }
					if (useScale) { scaleIndex = numValues; numValues ++; }
					if (useRotation) { rotationIndex = numValues; numValues ++; }
					if (useTransform) { transformIndex = numValues; numValues += 4; }
					if (useRGB) { rgbIndex = numValues; numValues += 3; }
					if (useAlpha) { alphaIndex = numValues; numValues ++; }
					
					var totalCount = c.tileData.length;
					if (c.count >= 0 && totalCount > c.count) totalCount = c.count;
					var itemCount = Std.int (totalCount / numValues);
					var index = 0;
					
					var rect = null;
					var center = null;
					var previousTileID = -1;
					
					var surface:Dynamic;
					c.sheet.__bitmap.__sync ();
					surface = c.sheet.__bitmap.getSurface ();
					
					cairo.save ();
					
					if (useBlendAdd) {
						
						cairo.operator = ADD;
						
					}
					
					if (useBlendOverlay) {
						
						cairo.operator = OVERLAY;
						
					}
					
					while (index < totalCount) {
						
						#if neko
						
						var f:Float = c.tileData[index + 2];
						var i = 0;
						
						if (f != null) {
							
							i = Std.int (f);
							
						}
						
						#else
						
						var i = Std.int (c.tileData[index + 2]);
						
						#end
						
						var tileID = (!useRect) ? i : -1;
						
						if (!useRect && tileID != previousTileID) {
							
							rect = c.sheet.__tileRects[tileID];
							center = c.sheet.__centerPoints[tileID];
							
							previousTileID = tileID;
							
						} else if (useRect) {
							
							rect = c.sheet.__rectTile;
							rect.setTo (c.tileData[index + 2], c.tileData[index + 3], c.tileData[index + 4], c.tileData[index + 5]);
							center = c.sheet.__point;
							
							if (useOrigin) {
								
								center.setTo (c.tileData[index + 6], c.tileData[index + 7]);
								
							} else {
								
								center.setTo (0, 0);
								
							}
							
						}
						
						if (rect != null && rect.width > 0 && rect.height > 0 && center != null) {
							
							// TODO: Handle rect, center, and offset X/Y properly based on matrix transform
							
							//cairo.save ();
							
							cairo.identityMatrix ();
							
							if (useTransform) {
								
								var matrix = new Matrix3 (c.tileData[index + transformIndex], c.tileData[index + transformIndex + 1], c.tileData[index + transformIndex + 2], c.tileData[index + transformIndex + 3], 0, 0);
								cairo.matrix = matrix;
								
							}
							
							cairo.translate (c.tileData[index] - offsetX, c.tileData[index + 1] - offsetY);
							
							if (useRotation) {
								
								cairo.rotate (c.tileData[index + rotationIndex]);
								
							}
							
							if (useScale) {
								
								var scale = c.tileData[index + scaleIndex];
								cairo.scale (scale, scale);
								
							}
							
							cairo.setSourceSurface (surface, 0, 0);
							
							if (useAlpha) {
								
								if (!hitTesting) cairo.paintWithAlpha (c.tileData[index + alphaIndex]);
								
							} else {
								
								if (!hitTesting) cairo.paint ();
								
							}
							
							//cairo.restore ();
							
						}
						
						index += numValues;
						
					}
					
					if (useBlendAdd || useBlendOverlay) {
						
						cairo.operator = OVER;
						
					}
					
					cairo.restore ();
				
				default:
					
					data.skip (type);
				
			}
			
		}
		
		data.destroy ();
		
		if (hasPath) {
			
			if (stroke && hasStroke) {
				
				if (hasFill && closeGap) {
					
					cairo.lineTo (startX - offsetX, startY - offsetY);
					
				}
				
				cairo.source = strokePattern;
				if (!hitTesting) cairo.strokePreserve ();
				
			}
			
			if (!stroke && hasFill) {
				
				cairo.translate (-bounds.x, -bounds.y);
				
				if (fillPatternMatrix != null) {
					
					var matrix = fillPatternMatrix.clone ();
					matrix.invert ();
					
					if (pendingMatrix != null) {
						
						matrix.concat (pendingMatrix);
						
					}
					
					fillPattern.matrix = matrix.__toMatrix3 ();
					
				}
				
				cairo.source = fillPattern;
				
				if (pendingMatrix != null) {
					
					cairo.transform (pendingMatrix.__toMatrix3 ());
					if (!hitTesting) cairo.fillPreserve ();
					cairo.transform (inversePendingMatrix.__toMatrix3 ());
					
				} else {
					
					if (!hitTesting) cairo.fillPreserve ();
					
				}
				
				cairo.translate (bounds.x, bounds.y);
				cairo.closePath ();
				
			}
			
		}
	}
	
	
	private static function quadraticCurveTo (cx:Float, cy:Float, x:Float, y:Float):Void {
		
		var current = null;
		
		if (!cairo.hasCurrentPoint) {
			
			cairo.moveTo (cx, cy);
			current = new Vector2 (cx, cy);
			
		} else {
			
			current = cairo.currentPoint;
			
		}
		
		var cx1 = current.x + ((2 / 3) * (cx - current.x));
		var cy1 = current.y + ((2 / 3) * (cy - current.y));
		var cx2 = x + ((2 / 3) * (cx - x));
		var cy2 = y + ((2 / 3) * (cy - y));
		
		cairo.curveTo (cx1, cy1, cx2, cy2, x, y);
		
	}
	
	
	public static function render (graphics:Graphics, renderSession:RenderSession):Void {
		
		#if lime_cairo
		CairoGraphics.graphics = graphics;
		
		if (!graphics.__dirty) return;
		
		bounds = graphics.__bounds;
		
		if (!graphics.__visible || graphics.__commands.length == 0 || bounds == null || bounds.width == 0 || bounds.height == 0) {
			
			if (graphics.__cairo != null) {
				
				graphics.__cairo.destroy ();
				graphics.__cairo = null;
				
			}
			
		} else {
			
			hitTesting = false;
			
			if (graphics.__cairo != null) {
				
				var surface:CairoImageSurface = cast graphics.__cairo.target;
				
				if (bounds.width != surface.width || bounds.height != surface.height) {
					
					graphics.__cairo.destroy ();
					graphics.__cairo = null;
					
				}
				
			}
			
			if (graphics.__cairo == null) {
				
				var bitmap = new BitmapData (Math.floor (bounds.width), Math.floor (bounds.height), true);
				var surface = bitmap.getSurface ();
				graphics.__cairo = new Cairo (surface);
				surface.destroy ();
				
				graphics.__bitmap = bitmap;
				
			}
			
			cairo = graphics.__cairo;
			
			cairo.operator = SOURCE;
			cairo.setSourceRGBA (1, 1, 1, 0);
			cairo.paint ();
			cairo.operator = OVER;
			
			fillCommands.clear();
			strokeCommands.clear();
			
			hasFill = false;
			hasStroke = false;
			
			fillPattern = null;
			strokePattern = null;
			
			var data = new DrawCommandReader (graphics.__commands);
			
			for (type in graphics.__commands.types) {
				
				switch (type) {
					
					case CUBIC_CURVE_TO:
						
						var c = data.readCubicCurveTo ();
						fillCommands.cubicCurveTo (c.controlX1, c.controlY1, c.controlX2, c.controlY2, c.anchorX, c.anchorY);
						strokeCommands.cubicCurveTo (c.controlX1, c.controlY1, c.controlX2, c.controlY2, c.anchorX, c.anchorY);
					
					case CURVE_TO:
						
						var c = data.readCurveTo ();
						fillCommands.curveTo (c.controlX, c.controlY, c.anchorX, c.anchorY);
						strokeCommands.curveTo (c.controlX, c.controlY, c.anchorX, c.anchorY);
					
					case LINE_TO:
						
						var c = data.readLineTo ();
						fillCommands.lineTo (c.x, c.y);
						strokeCommands.lineTo (c.x, c.y);
					
					case MOVE_TO:
						
						var c = data.readMoveTo ();
						fillCommands.moveTo (c.x, c.y);
						strokeCommands.moveTo (c.x, c.y);
					
					case END_FILL:
						
						data.readEndFill ();
						endFill ();
						endStroke ();
						hasFill = false;
						bitmapFill = null;
					
					case LINE_GRADIENT_STYLE:
						
						var c = data.readLineGradientStyle ();
						strokeCommands.lineGradientStyle (c.type, c.colors, c.alphas, c.ratios, c.matrix, c.spreadMethod, c.interpolationMethod, c.focalPointRatio);
						
					case LINE_BITMAP_STYLE:
						
						var c = data.readLineBitmapStyle ();
						strokeCommands.lineBitmapStyle (c.bitmap, c.matrix, c.repeat, c.smooth);
					
					case LINE_STYLE:
						
						var c = data.readLineStyle ();
						strokeCommands.lineStyle (c.thickness, c.color, c.alpha, c.pixelHinting, c.scaleMode, c.caps, c.joints, c.miterLimit);
					
					case BEGIN_BITMAP_FILL, BEGIN_FILL, BEGIN_GRADIENT_FILL:
						
						endFill ();
						endStroke ();
						
						if (type == BEGIN_BITMAP_FILL) {
							
							var c = data.readBeginBitmapFill ();
							fillCommands.beginBitmapFill (c.bitmap, c.matrix, c.repeat, c.smooth);
							strokeCommands.beginBitmapFill (c.bitmap, c.matrix, c.repeat, c.smooth);
							
						} else if (type == BEGIN_GRADIENT_FILL) {
							
							var c = data.readBeginGradientFill ();
							fillCommands.beginGradientFill (c.type, c.colors, c.alphas, c.ratios, c.matrix, c.spreadMethod, c.interpolationMethod, c.focalPointRatio);
							strokeCommands.beginGradientFill (c.type, c.colors, c.alphas, c.ratios, c.matrix, c.spreadMethod, c.interpolationMethod, c.focalPointRatio);
							
						} else {
							
							var c = data.readBeginFill ();
							fillCommands.beginFill (c.color, c.alpha);
							strokeCommands.beginFill (c.color, c.alpha);
							
						}
					
					case DRAW_CIRCLE:
						
						var c = data.readDrawCircle ();
						fillCommands.drawCircle (c.x, c.y, c.radius);
						strokeCommands.drawCircle (c.x, c.y, c.radius);
					
					case DRAW_ELLIPSE:
						
						var c = data.readDrawEllipse ();
						fillCommands.drawEllipse (c.x, c.y, c.width, c.height);
						strokeCommands.drawEllipse (c.x, c.y, c.width, c.height);
					
					case DRAW_RECT:
						
						var c = data.readDrawRect ();
						fillCommands.drawRect (c.x, c.y, c.width, c.height);
						strokeCommands.drawRect (c.x, c.y, c.width, c.height);
					
					case DRAW_ROUND_RECT:
						
						var c = data.readDrawRoundRect ();
						fillCommands.drawRoundRect (c.x, c.y, c.width, c.height, c.rx, c.ry);
						strokeCommands.drawRoundRect (c.x, c.y, c.width, c.height, c.rx, c.ry);
					
					case DRAW_TILES:
						
						var c = data.readDrawTiles ();
						fillCommands.drawTiles (c.sheet, c.tileData, c.smooth, c.flags, c.count);
					
					case DRAW_TRIANGLES:
						
						var c = data.readDrawTriangles ();
						fillCommands.drawTriangles (c.vertices, c.indices, c.uvtData, c.culling, c.colors, c.blendMode);
					
					default:
						
						data.skip (type);
					
				}
				
			}
			
			if (fillCommands.length > 0) {
				
				endFill ();
				
			}
			
			if (strokeCommands.length > 0) {
				
				endStroke ();
				
			}
			
			data.destroy ();
			
			graphics.__bitmap.image.dirty = true;
			
		}
		
		graphics.__dirty = false;
		
		#end
		
	}
	
	
	public static function renderMask (graphics:Graphics, renderSession:RenderSession) {
		
		if (graphics.__commands.length != 0) {
			
			var cairo = renderSession.cairo;
			
			var positionX = 0.0;
			var positionY = 0.0;
			
			var offsetX = 0;
			var offsetY = 0;
			
			var data = new DrawCommandReader(graphics.__commands);
			
			for (type in graphics.__commands.types) {
				
				switch (type) {
					
					case CUBIC_CURVE_TO:
						
						var c = data.readCubicCurveTo ();
						cairo.curveTo (c.controlX1 - offsetX, c.controlY1 - offsetY, c.controlX2 - offsetX, c.controlY2 - offsetY, c.anchorX - offsetX, c.anchorY - offsetY);
						positionX = c.anchorX;
						positionY = c.anchorX;
					
					case CURVE_TO:
						
						var c = data.readCurveTo ();
						quadraticCurveTo (c.controlX - offsetX, c.controlY - offsetY, c.anchorX - offsetX, c.anchorY - offsetY);
						positionX = c.anchorX;
						positionY = c.anchorY;
					
					case DRAW_CIRCLE:
					
						var c = data.readDrawCircle ();
						cairo.arc (c.x - offsetX, c.y - offsetY, c.radius, 0, Math.PI * 2);
					
					case DRAW_ELLIPSE:
						
						var c = data.readDrawEllipse ();
						
						var x = c.x;
						var y = c.y;
						var width = c.width;
						var height = c.height;
						
						x -= offsetX;
						y -= offsetY;
						
						var kappa = .5522848,
							ox = (width / 2) * kappa, // control point offset horizontal
							oy = (height / 2) * kappa, // control point offset vertical
							xe = x + width,           // x-end
							ye = y + height,           // y-end
							xm = x + width / 2,       // x-middle
							ym = y + height / 2;       // y-middle
						
						//closePath (false);
						//beginPath ();
						cairo.moveTo (x, ym);
						cairo.curveTo (x, ym - oy, xm - ox, y, xm, y);
						cairo.curveTo (xm + ox, y, xe, ym - oy, xe, ym);
						cairo.curveTo (xe, ym + oy, xm + ox, ye, xm, ye);
						cairo.curveTo (xm - ox, ye, x, ym + oy, x, ym);
						//closePath (false);
					
					case DRAW_RECT:
						
						var c = data.readDrawRect ();
						cairo.rectangle (c.x - offsetX, c.y - offsetY, c.width, c.height);
					
					case DRAW_ROUND_RECT:
						
						var c = data.readDrawRoundRect ();
						drawRoundRect (c.x - offsetX, c.y - offsetY, c.width, c.height, c.rx, c.ry);
					
					case LINE_TO:
						
						var c = data.readLineTo ();
						cairo.lineTo (c.x - offsetX, c.y - offsetY);
						positionX = c.x;
						positionY = c.y;
						
					case MOVE_TO:
						
						var c = data.readMoveTo ();
						cairo.moveTo (c.x - offsetX, c.y - offsetY);
						positionX = c.x;
						positionY = c.y;
					
					default:
						
						data.skip (type);
					
				}
				
			}
			
			data.destroy();
		}
	}
	
	
}