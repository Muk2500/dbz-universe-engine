/**
 * Procedural Physics Simulation Engine (Z-Runner)
 * 
 * Utilizes an ENTER_FRAME loop for continuous physics calculations.
 * Implements custom Axis-Aligned Bounding Box (AABB) intersection math
 * for real-time collision detection, avoiding native hitTest overhead.
 * Handles procedural memory management for spawned obstacle entities.
 */
package games {
    import flash.display.*;
    import flash.events.*;
    import flash.text.*;
    import flash.net.URLRequest;
    import flash.media.Sound;
    import flash.filters.GlowFilter;
    import flash.geom.ColorTransform;
    import flash.geom.Point;
    import flash.utils.Timer;
    import flash.system.*;

    // High-speed ground runner - jump over low blasts, duck under high blasts!
    public class ZRunner extends MovieClip {

        private const W:int   = 1280;
        private const H:int   = 720;
        private const FLOOR:int = 560;
        private const PLAYER_X:int = 150;
        private const GRAVITY:Number = 0.8;
        private const JUMP_FORCE:Number = -13.5;

        private var velocityY:Number = 0;
        private var playerY:Number   = FLOOR;
        private var isJumping:Boolean = false;
        
        private function playSnd(names:Array):void {
            for each (var nm:String in names) {
                try { var Cls:Class = flash.utils.getDefinitionByName(nm) as Class; if(Cls){ var snd:Sound = new Cls(); snd.play(); return; } } catch(err:Error) {}
            }
        }

        private var speed:Number     = 10;
          private var friezaHoverOffset:Number = 0;
        private var score:int        = 0;
        private var running:Boolean  = false;
        private var started:Boolean  = false;
        private var frameCount:int   = 0;
        private static var best:int  = 0;
        private static var bmdCache:Object = {};
        
        // Kaioken State
        private var isKaioken:Boolean = false;
        private var kaiokenTimer:int = 0;

        // Obstacles {sprite:Sprite, passed:Boolean, type:String ("HIGH" or "LOW"), x:Number, y:Number}
        private var obstacles:Array = [];
        private var spawnTimer:int = 0;
        private var currentSpawnRate:int = 70; // gets faster!

        private var bgLayer:Sprite;
        private var floorLayer:Sprite;
        private var friezaLayer:Sprite;
        private var obsLayer:Sprite;
        private var pLayer:Sprite;
        private var player_mc:Sprite;
        private var playerGraphic:Sprite;
        private var gokuBaseSp:Sprite;
        private var gokuKaioSp:Sprite;

        private var scoreTF:TextField;
        private var bestTF:TextField;
        private var statusTF:TextField;
        private var tapTF:TextField;
        private var kaiokenTF:TextField;

        public function ZRunner() {
            addEventListener(Event.ADDED_TO_STAGE, onAdded);
        }

        private function onAdded(e:Event):void {
            removeEventListener(Event.ADDED_TO_STAGE, onAdded);

            // Sky background
            graphics.beginFill(0x000820);
            graphics.drawRect(0, 0, W, H);
            graphics.endFill();

            bgLayer = new Sprite();
            addChild(bgLayer);
            
            // Seamless Sky Background Loading
            for(var b:int = 0; b < 3; b++) {
                (function(idx:int):void {
                    var bgWrapper:Sprite = new Sprite();
                    bgWrapper.scaleX = 1.25;
                    bgWrapper.scaleY = 0.703125;
                    bgWrapper.x = idx * 1280;
                    bgLayer.addChild(bgWrapper);
                    
                    var bgLdr:flash.display.Loader = new flash.display.Loader();
                    bgWrapper.addChild(bgLdr);
                    
                    var bgPaths:Array = [
                        "games/assets/sky_bg.png",
                        "../games/assets/sky_bg.png",
                        "as3/games/assets/sky_bg.png",
                        "C:/Users/10muk/Downloads/dragonball/as3/games/assets/sky_bg.png"
                    ];
                    var bgIndex:int = 0;
                    var bgTryNext:Function = function(e:IOErrorEvent):void {
                        bgIndex++;
                        if (bgIndex < bgPaths.length) {
                            try { bgLdr.load(new flash.net.URLRequest(bgPaths[bgIndex])); } catch(err:Error){}
                        } else {
                            bgLdr.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, bgTryNext);
                        }
                    };
                    bgLdr.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, bgTryNext);
                    try { bgLdr.load(new flash.net.URLRequest(bgPaths[bgIndex])); } catch(err:Error){}
                })(b);
            }
            // Seamless Snake Way horizontal tiled floor
            floorLayer = new Sprite();
            addChild(floorLayer);
            for (var f:int = 0; f < 2; f++) {
                var segment:Sprite = new Sprite();
                segment.graphics.beginFill(0xFFD700); // Gold
                segment.graphics.drawRect(0, 0, W, H - FLOOR);
                segment.graphics.endFill();
                
                segment.graphics.lineStyle(2, 0xB8860B); // Top Edge
                segment.graphics.moveTo(0, 0); segment.graphics.lineTo(W, 0);
                
                segment.graphics.lineStyle(1, 0xDAA520); // Brick lines
                for (var ty:int = 0; ty < H - FLOOR; ty += 20) {
                    segment.graphics.moveTo(0, ty); segment.graphics.lineTo(W, ty);
                    var offset:int = (ty % 40 == 0) ? 0 : 30;
                    for (var tx:int = offset; tx < W; tx += 60) {
                        segment.graphics.moveTo(tx, ty); segment.graphics.lineTo(tx, ty + 20);
                    }
                }
                segment.x = f * W;
                segment.y = FLOOR;
                floorLayer.addChild(segment);
            }
            // HUD
            var rl:TextField = makeTF(":: SNAKE WAY: EVASION TRAINING ::", 0, FLOOR+6, W, 30, 0xFF69B4, 16, true, "center");
            addChild(rl);

            friezaLayer = new Sprite(); addChild(friezaLayer);
            buildFrieza();

            obsLayer = new Sprite(); addChild(obsLayer);
            pLayer   = new Sprite(); addChild(pLayer);

            player_mc = buildPlayer();
            pLayer.addChild(player_mc);

            scoreTF  = makeTF("SCORE: 0", 20, 20, 200, 40, 0xFFFFFF, 32, true, "left");
            bestTF   = makeTF("BEST: 0",  20, 54, 280, 28, 0xFFD700, 16, true, "left");
            tapTF    = makeTF("SPACE TO JUMP", 0, 300, W, 50, 0x00BFFF, 30, true, "center");
            statusTF = makeTF("", 0, 220, W, 90, 0xFF2020, 52, true, "center");
            kaiokenTF = makeTF("", 0, 150, W, 100, 0xFF2020, 72, true, "center");
            kaiokenTF.filters = [new GlowFilter(0xFF0000, 1, 10, 10, 1.5)];
            
            bestTF.text = "BEST: " + best;
            addChild(scoreTF); addChild(bestTF); addChild(tapTF); addChild(statusTF); addChild(kaiokenTF);

            // Exit button
            var quit:Sprite = new Sprite();
            quit.graphics.beginFill(0xFF0000);
            quit.graphics.drawRoundRect(0,0,80,30,8,8);
            quit.graphics.endFill();
            var qtf:TextField = makeTF("EXIT", 0, 6, 80, 18, 0xFFFFFF, 14, true, "center");
            quit.addChild(qtf);
            quit.x = W - 100; quit.y = 20;
            quit.buttonMode = true; quit.mouseChildren = false;
            quit.addEventListener(MouseEvent.CLICK, function(ev:MouseEvent):void {
                stopGame();
                dispatchEvent(new Event("EXIT_GAME", true)); // Dispatch to Main
            });
            addChild(quit);

            stage.addEventListener(KeyboardEvent.KEY_DOWN, handleKeyDown);
            stage.addEventListener(KeyboardEvent.KEY_UP, handleKeyUp);
            addEventListener(Event.ENTER_FRAME, loop);
        }

                                        private function loadImageWithKey(url:String, targ:Sprite, w:Number, h:Number, ox:Number, oy:Number):void {
            if (bmdCache[url]) {
                var cb:Bitmap = new Bitmap(bmdCache[url]); cb.smoothing = true;
                cb.width = w; cb.height = h;
                cb.x = ox; cb.y = oy;
                targ.addChild(cb);
                return;
            }

            var paths:Array = [
                url,
                "../" + url,
                "as3/" + url,
                "C:/Users/10muk/Downloads/dragonball/as3/" + url
            ];
            var pathIndex:int = 0;
            var urlLdr:flash.net.URLLoader = new flash.net.URLLoader();
            urlLdr.dataFormat = flash.net.URLLoaderDataFormat.BINARY;
            
            var tryNext:Function = function(e:IOErrorEvent = null):void {
                if (pathIndex < paths.length) {
                    var req:flash.net.URLRequest = new flash.net.URLRequest(paths[pathIndex++]);
                    try { urlLdr.load(req); } catch(err:Error){ tryNext(); }
                }
            };
            
            urlLdr.addEventListener(IOErrorEvent.IO_ERROR, tryNext);
            urlLdr.addEventListener(Event.COMPLETE, function(e:Event):void {
                var ldr:flash.display.Loader = new flash.display.Loader();
                ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, function(le:Event):void {
                    var bmp:Bitmap = le.currentTarget.content as Bitmap;
                    if (bmp) {
                        var bmd:BitmapData = bmp.bitmapData;
                        var transpBmd:BitmapData = new BitmapData(bmd.width, bmd.height, true, 0x00000000);
                        transpBmd.draw(bmd);
                        
                        var bgColor:uint = transpBmd.getPixel32(0, 0);
                        var bgR:int = (bgColor >> 16) & 0xFF;
                        var bgG:int = (bgColor >> 8) & 0xFF;
                        var bgB:int = bgColor & 0xFF;
                        
                        transpBmd.lock();
                        for (var py:int = 0; py < bmd.height; py++) {
                            for (var px:int = 0; px < bmd.width; px++) {
                                var c:uint = transpBmd.getPixel32(px, py);
                                var r:int = (c >> 16) & 0xFF;
                                var g:int = (c >> 8) & 0xFF;
                                var b:int = c & 0xFF;
                                
                                var dr:int = r - bgR;
                                var dg:int = g - bgG;
                                var db:int = b - bgB;
                                if (Math.sqrt(dr*dr + dg*dg + db*db) < 20) {
                                    transpBmd.setPixel32(px, py, 0x00000000);
                                }
                            }
                        }
                        transpBmd.unlock();
                        
                        bmdCache[url] = transpBmd;
                        
                        var cleanBmp:Bitmap = new Bitmap(transpBmd); cleanBmp.smoothing = true;
                        cleanBmp.width = w; cleanBmp.height = h;
                        cleanBmp.x = ox; cleanBmp.y = oy;
                        targ.addChild(cleanBmp);
                    }
                });
                var loaderContext:flash.system.LoaderContext = new flash.system.LoaderContext(false, flash.system.ApplicationDomain.currentDomain);
                if (loaderContext.hasOwnProperty("allowCodeImport")) {
                    loaderContext["allowCodeImport"] = true;
                }
                ldr.loadBytes(urlLdr.data as flash.utils.ByteArray, loaderContext);
            });
            
            tryNext();
        }

        private function buildPlayer():Sprite {
            var s:Sprite = new Sprite();
            playerGraphic = new Sprite();
            
            gokuBaseSp = new Sprite();
            loadImageWithKey("games/assets/goku_v3.png", gokuBaseSp, 120, 120, -60, -90);
            playerGraphic.addChild(gokuBaseSp);
            
            gokuKaioSp = new Sprite();
            loadImageWithKey("games/assets/goku_kaioken.png", gokuKaioSp, 160, 160, -80, -110);
            gokuKaioSp.visible = false;
            playerGraphic.addChild(gokuKaioSp);
            
            s.addChild(playerGraphic);
            s.x = 200; s.y = FLOOR;
            
            return s;
        }

        private function buildFrieza():void {
            loadImageWithKey("games/assets/frieza_shoot.png", friezaLayer, 150, 150, -75, -75);
            
            friezaLayer.x = W - 150;
            friezaLayer.y = FLOOR - 20;
            friezaLayer.filters = [new GlowFilter(0x9B30FF, 0.5, 30, 30, 1)];
        }

// ----------------------------------------------------------------------------------
        private function loop(e:Event):void {
            if (!running) {
                if (started) {
                    player_mc.y = FLOOR; // dead on ground
                } else {
                    player_mc.y = FLOOR + Math.sin(frameCount * 0.1) * 5; // idle breathing
                }
                frameCount++;
                return;
            }

            // Physics (Gravity & Jumping)
            if (isJumping) {
                velocityY += GRAVITY;
                playerY += velocityY;
                if (playerY >= FLOOR) {
                    playerY = FLOOR;
                    isJumping = false;
                    velocityY = 0;
                }
            }
            player_mc.y = playerY;

            playerGraphic.scaleY = 1.0;

            // Floor movement (Foreground fast speed)
            for (var fi:int = 0; fi < floorLayer.numChildren; fi++) {
                var floorSeg:DisplayObject = floorLayer.getChildAt(fi);
                floorSeg.x -= speed;
                if (floorSeg.x <= -W) floorSeg.x += W * 2;
            }

            // Sky movement (Background parallax slow speed)
            if (bgLayer) {
                for (var bi:int = 0; bi < bgLayer.numChildren; bi++) {
                    var child:DisplayObject = bgLayer.getChildAt(bi);
                    child.x -= (speed * 0.15); // Parallax
                    if (child.x <= -1280) child.x += 1280 * 3;
                }
            }

            // Frieza hover animation
            if (friezaHoverOffset > 0) friezaHoverOffset -= 3;
              friezaLayer.y = FLOOR - 20 - friezaHoverOffset + Math.sin(frameCount * 0.2) * 10;
            
            // Kaioken Logic
            if (isKaioken) {
                gokuBaseSp.visible = false;
                gokuKaioSp.visible = true;
                kaiokenTimer--;
                if (kaiokenTimer <= 0) {
                    isKaioken = false;
                    gokuBaseSp.visible = true;
                    gokuKaioSp.visible = false;
                    kaiokenTF.text = "";
                    speed = 10 + (score * 0.4); // Reset speed
                } else if (kaiokenTimer % 10 < 5) {
                    kaiokenTF.text = "KAIOKEN!"; // Flicker
                } else {
                    kaiokenTF.text = "";
                }
            }

            // Spawn obstacles
            frameCount++;
            spawnTimer++;
            if (spawnTimer >= currentSpawnRate) {
                spawnObstacle();
                spawnTimer = 0;
                // Slowly increase spawn rate and speed
                if (currentSpawnRate > 35) currentSpawnRate -= 2;
            }

            // Move obstacles & check collision
            for (var i:int = obstacles.length - 1; i >= 0; i--) {
                var obs:Object = obstacles[i];
                obs.x -= speed;
                obs.sprite.x = obs.x;

                // Score when passed
                if (!obs.passed && obs.x < PLAYER_X - 30) {
                    obs.passed = true;
                    score++;
                    if (score > best) best = score;
                    scoreTF.text = "SCORE: " + score;
                    bestTF.text  = "BEST: "  + best;
                    speed = 10 + (score * 0.4); // speed up!
                }

                // Collision Detection
                // Player Hitbox (approx 40 width, fixed height)
                var pTop:Number = player_mc.y - 70;
                var pBot:Number = player_mc.y;
                var pLeft:Number = player_mc.x - 20;
                var pRight:Number = player_mc.x + 20;

                // Obstacle Hitbox (approx 40 width)
                var oTop:Number = obs.y - 20;
                var oBot:Number = obs.y + 20;
                var oLeft:Number = obs.x - 20;
                var oRight:Number = obs.x + 20;

                if (pRight > oLeft && pLeft < oRight) { // X overlap
                    if (pBot > oTop && pTop < oBot) { // Y overlap
                        if (obs.type == "SENZU") {
                            playSnd(["senzu2_wav", "senzu2", "Senzu2"]);
                            playSnd(["kaioken1_wav", "kaioken1", "Kaioken1"]);
                            activateKaioken();
                            obsLayer.removeChild(obs.sprite);
                            obstacles.splice(i, 1);
                            continue;
                        } else if (!isKaioken) {
                            die();
                            return;
                        }
                    }
                }

                // Remove off-screen
                if (obs.x < -100) {
                    obsLayer.removeChild(obs.sprite);
                    obstacles.splice(i, 1);
                }
            }
        }

        private function spawnObstacle():void {
            var r:Number = Math.random();
            var type:String = "LOW";
            if (r > 0.90) type = "SENZU";
            else if (r > 0.45) type = "HIGH";
            
            var obsY:Number = FLOOR - 15;
            if (type == "HIGH") { obsY = 415; friezaHoverOffset = 100; } // Centered to match oTop/oBot
            if (type == "SENZU") obsY = FLOOR - 30 - Math.random() * 50;
            
            var s:Sprite = new Sprite();
            
            if (type == "SENZU") {
                loadImageWithKey("games/assets/senzu_bean.png", s, 40, 40, -20, -20);
            } else if (type == "HIGH") {
                loadImageWithKey("games/assets/ki_blast.png", s, 60, 60, -30, -30);
            } else {
                loadImageWithKey("games/assets/ki_blast.png", s, 60, 60, -30, -30);
            }
            
            s.x = friezaLayer.x - 20;
            s.y = obsY;
            obsLayer.addChild(s);
            
            obstacles.push({sprite:s, x:s.x, y:obsY, passed:false, type:type});
        }

        private function activateKaioken():void {
            isKaioken = true;
            kaiokenTimer = 360; // 6 seconds at 60fps
            speed *= 1.5; // +50% speed
            kaiokenTF.text = "KAIOKEN!";
            
            var shake:Timer = new Timer(30, 5);
            var stx:Number = this.x;
            var sty:Number = this.y;
            shake.addEventListener(TimerEvent.TIMER, function(e:Event):void {
                x = stx + (Math.random() * 10 - 5);
                y = sty + (Math.random() * 10 - 5);
            });
            shake.addEventListener(TimerEvent.TIMER_COMPLETE, function(e:Event):void {
                x = stx; y = sty;
            });
            shake.start();
        }

        private function die():void {
            running = false;
            playSnd(["shockwave2_wav", "shockwave2", "Shockwave2"]);
            
            // Screen shake
            var stx:Number = this.x;
            var shake:Timer = new Timer(30, 10);
            shake.addEventListener(TimerEvent.TIMER, function(e:Event):void {
                x = stx + (Math.random() * 20 - 10);
            });
            shake.addEventListener(TimerEvent.TIMER_COMPLETE, function(e:Event):void {
                x = stx;
            });
            shake.start();

            statusTF.text = "KO!\nSCORE " + score;
            tapTF.text = "[SPACE] TO RETRY";
            tapTF.textColor = 0xFFD700;
        }

// ----------------------------------------------------------------------------------
        private function handleKeyDown(e:KeyboardEvent):void {
            if (e.keyCode == 32 || e.keyCode == 38) { // SPACE or UP
                if (!running && !started) {
                    startGame();
                } else if (!running && started) {
                    resetState(); startGame();
                } else if (!isJumping) {
                    isJumping = true;
                    velocityY = JUMP_FORCE;
                }
            }
        }

        private function handleKeyUp(e:KeyboardEvent):void {
        }

        private function startGame():void {
            started = true;
            running = true;
            tapTF.text = "";
            statusTF.text = "";
        }

        private function resetState():void {
            score = 0; velocityY = 0; playerY = FLOOR; frameCount = 0; speed = 10;
            currentSpawnRate = 70; spawnTimer = 0;
            isJumping = false;
            isKaioken = false; kaiokenTF.text = "";
            player_mc.transform.colorTransform = new ColorTransform();
            playerGraphic.scaleY = 1.0;
            player_mc.y = playerY; 
            scoreTF.text = "SCORE: 0";
            while (obsLayer.numChildren > 0) obsLayer.removeChildAt(0);
            obstacles = [];
        }

        public function startRun():void {
            resetState();
            started = false; running = false;
            tapTF.text = "SPACE TO JUMP";
            statusTF.text = "";
        }

        public function stopGame():void {
            running = false;
            if (stage) {
                stage.removeEventListener(KeyboardEvent.KEY_DOWN, handleKeyDown);
                stage.removeEventListener(KeyboardEvent.KEY_UP, handleKeyUp);
            }
            removeEventListener(Event.ENTER_FRAME, loop);
        }

        private function makeTF(txt:String, x:Number, y:Number, w:Number, h:Number, color:uint, size:int, bold:Boolean=false, align:String="left"):TextField {
            var tf:TextField = new TextField();
            var fmt:TextFormat = new TextFormat("Orbitron", size, color, bold);
            fmt.align = align;
            tf.defaultTextFormat = fmt;
            tf.text=txt; tf.x=x; tf.y=y; tf.width=w; tf.height=h;
            tf.selectable=false; tf.mouseEnabled=false;
            
            tf.embedFonts = false;
            
            return tf;
        }
    }
}

















