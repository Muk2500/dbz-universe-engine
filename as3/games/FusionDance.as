/**
 * Asynchronous Rhythm Simulation (Fusion Dance)
 * 
 * Implements millisecond-precision logic using the Timer class to 
 * create strict 'Action Windows' for user input evaluation.
 * Calculates algorithmic performance scoring to trigger dynamic 
 * sprite state transitions upon success or failure.
 */
package games {
    import flash.display.*;
    import flash.events.*;
    import flash.utils.Timer;
    import flash.text.*;
    import flash.net.URLRequest;
    import flash.filters.GlowFilter;
    import flash.geom.Point;
    import flash.system.*;
    import flash.utils.*;

    public class FusionDance extends Sprite {
        private var isRunning:Boolean = false;
        private var step:int = 0;
        private var hits:int = 0;
        private var isAwaitingKey:Boolean = false;
        private var beatTimer:Timer;
        private var windowTimer:Timer;
        private const BEATS:Array = [37, 39, 38, 40, 37, 39]; // L R U D L R

        private static var bestScore:int = 0; // persists across plays

        private var p1:Sprite; // starts LEFT, moves RIGHT => toward centre
        private var p2:Sprite; // starts RIGHT, moves LEFT => toward centre
        private var p3:Sprite; // Gogeta, hidden until success
        private var p4:Sprite; // Veku, hidden until failure
        private var statusTF:TextField;
        private var beatTF:TextField;
        private var scoreTF:TextField;
        private var highTF:TextField;
        private var quitBtn:Sprite;

        public function FusionDance() {
            addEventListener(Event.ADDED_TO_STAGE, init);
        }

        private function init(e:Event):void {
            removeEventListener(Event.ADDED_TO_STAGE, init);

            // Background image
            var bgLdr:Loader = new Loader();
            loadSmart(bgLdr, "fusion/fusion_bg.jpg");
            addChild(bgLdr);
            
            // Dark overlay to ensure text is readable
            var darkOverlay:Shape = new Shape();
            darkOverlay.graphics.beginFill(0x0a0a14, 0.4);
            darkOverlay.graphics.drawRect(0, 0, 1280, 720);
            darkOverlay.graphics.endFill();
            addChild(darkOverlay);

            // Two fighters – start at opposite edges, meet in the CENTRE
            p1 = buildFighter("fusion/goku_fusion.png", 0xFF8C00);
            p2 = buildFighter("fusion/vegeta_fusion.png", 0x00BFFF);
            p3 = buildFighter("fusion/gogeta_fusion.png", 0xFFD700, 80); // Push Gogeta down 80px
            p4 = buildFighter("fusion/veku.png", 0xFF0000, 80);
            resetPositions();
            addChild(p1);
            addChild(p2);
            addChild(p3);
            addChild(p4);

            statusTF = mkTF("FUSION RITUAL",        0, 90,  1280, 60, 0xFFD700, 44);
            beatTF   = mkTF("GET READY...",         0, 180, 1280, 56, 0x00FF41, 42);
            scoreTF  = mkTF("RHYTHM: 0 / 6",        0, 258, 1280, 36, 0x888888, 22);
            highTF   = mkTF("BEST: " + bestScore + " / 6", 0, 296, 1280, 30, 0xFFD700, 18);

            addChild(statusTF);
            addChild(beatTF);
            addChild(scoreTF);
            addChild(highTF);

            // Arrow legend at the bottom
            addChild(mkTF("LEFT    RIGHT    UP    DOWN",
                0, 630, 1280, 30, 0x444466, 14));

            quitBtn = makeQuit();
            addChild(quitBtn);
        }

        // fighters start at extreme edges; 6 total steps of 187px
        // means they meet at x≈640 (centre) after step 3, then cross
        private function resetPositions():void {
            p1.x = 80;   p1.y = 460; // far left
            p2.x = 1200; p2.y = 460; // far right
            p1.visible = true;
            p2.visible = true;
            p3.visible = false;
            p4.visible = false;
            p3.x = 640; p3.y = 460;
            p4.x = 640; p4.y = 460;
        }

        private function loadSmart(ldr:Loader, path:String):void {
            var attemptPaths:Array = ["../assets/" + path, "assets/" + path, "../../assets/" + path];
            var pathIdx:int = 0;
            var urlLdr:flash.net.URLLoader = new flash.net.URLLoader();
            urlLdr.dataFormat = flash.net.URLLoaderDataFormat.BINARY;
            var tryNextPath:Function = function(e:Event = null):void {
                if (pathIdx < attemptPaths.length) {
                    try { urlLdr.load(new URLRequest(attemptPaths[pathIdx++])); } catch(err:Error) { tryNextPath(); }
                }
            };
            urlLdr.addEventListener(IOErrorEvent.IO_ERROR, tryNextPath);
            urlLdr.addEventListener(Event.COMPLETE, function(e:Event):void {
                var loaderContext:flash.system.LoaderContext = new flash.system.LoaderContext(false, flash.system.ApplicationDomain.currentDomain);
                if (loaderContext.hasOwnProperty("allowCodeImport")) loaderContext["allowCodeImport"] = true;
                ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, function(ev:Event):void {
                    if (ldr.content is flash.display.Bitmap) {
                        (ldr.content as flash.display.Bitmap).smoothing = true;
                    }
                });
                ldr.loadBytes(urlLdr.data as flash.utils.ByteArray, loaderContext);
            });
            tryNextPath();
        }

        private function buildFighter(imgPath:String, color:uint, yOffset:Number = 0):Sprite {
            var s:Sprite = new Sprite();
            // Aura circle
            s.graphics.beginFill(color, 0.18);
            s.graphics.drawCircle(0, 0, 90);
            s.graphics.endFill();
            s.graphics.lineStyle(2, color, 0.6);
            s.graphics.drawCircle(0, 0, 90);

            var ldr:Loader = new Loader();
            ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, function(ev:Event):void {
                var w:Number = ldr.contentLoaderInfo.width;
                var h:Number = ldr.contentLoaderInfo.height;
                var scaleFactor:Number = 250 / h;
                
                // Scale the wrapper sprite s instead of the Loader to avoid local file scaling errors
                s.scaleX = scaleFactor;
                s.scaleY = scaleFactor;
                
                ldr.x = -(w / 2);
                ldr.y = -h + ((60 + yOffset) / scaleFactor);
                
                s.addChild(ldr);
            });
            loadSmart(ldr, imgPath);
            return s;
        }

        private function makeQuit():Sprite {
            var q:Sprite = new Sprite();
            q.graphics.beginFill(0x220000); q.graphics.drawRect(0,0,110,32); q.graphics.endFill();
            q.graphics.lineStyle(1, 0xFF2020, 0.5); q.graphics.drawRect(0,0,110,32);
            var qtf:TextField = new TextField();
            qtf.defaultTextFormat = new TextFormat("Orbitron", 11, 0xFF2020, true); qtf.embedFonts = false;
            qtf.text = "EXIT GAME"; qtf.width = 110; qtf.selectable = false;
            qtf.y = 8; qtf.mouseEnabled = false;
            q.addChild(qtf);
            q.x = 20; q.y = 20; q.buttonMode = true; q.mouseChildren = false;
            q.addEventListener(MouseEvent.CLICK, function(me:MouseEvent):void {
                stopGame();
                dispatchEvent(new Event("EXIT_GAME"));
            });
            return q;
        }

        private function mkTF(t:String,x:Number,y:Number,w:Number,h:Number,c:uint,
                               sz:Number=14):TextField {
            var tf:TextField = new TextField();
            var fmt:TextFormat = new TextFormat("Orbitron", sz, c, true);
            fmt.align = "center";
            tf.defaultTextFormat = fmt; tf.embedFonts = false;
            tf.text=t; tf.x=x; tf.y=y; tf.width=w; tf.height=h;
            tf.selectable=false; tf.mouseEnabled=false;
            tf.filters=[new GlowFilter(c, 0.4, 6, 6, 1)];
            return tf;
        }

// ----------------------------------------------------------------------------------
        public function startFusion():void {
            resetPositions();
            isRunning=true; step=0; hits=0;
            scoreTF.text = "RHYTHM: 0 / " + BEATS.length;
            statusTF.text = ":: STRIKE ON BEAT! ::";
            stage.addEventListener(KeyboardEvent.KEY_DOWN, handleKeyDown);
            runNextBeat();
        }

        public function stopGame():void {
            isRunning=false;
            if (windowTimer) windowTimer.stop();
            if (beatTimer)   beatTimer.stop();
            if (stage) stage.removeEventListener(KeyboardEvent.KEY_DOWN, handleKeyDown);
        }

// ----------------------------------------------------------------------------------
        private function runNextBeat():void {
            if (!isRunning) return;
            if (step >= BEATS.length) { endFusion(); return; }

            var labels:Object = {37:"LEFT", 38:"UP", 39:"RIGHT", 40:"DOWN"};
            beatTF.text = labels[BEATS[step]];
            beatTF.textColor = 0x00BFFF;
            isAwaitingKey = true;

            windowTimer = new Timer(1200, 1);
            windowTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onTimeExpired);
            windowTimer.start();
        }

        private function handleKeyDown(e:KeyboardEvent):void {
            if (!isRunning || !isAwaitingKey) return;
            isAwaitingKey = false;
            if (windowTimer) windowTimer.stop();

            if (e.keyCode == BEATS[step]) {
                hits++;
                beatTF.text = "PERFECT!"; beatTF.textColor = 0x00FF41;
                try { if (Object(root).hasOwnProperty("playClick")) Object(root).playClick(); } catch(err:Error) {}
                
                // 80px per hit: after 6, they meet perfectly at the center without crossing
                // p1 starts 80 -> reaches 560. p2 starts 1200 -> reaches 720.
                p1.x += 80;
                p2.x -= 80;
            } else {
                beatTF.text = "FAILURE!"; beatTF.textColor = 0xFF0000;
            }
            scoreTF.text = "RHYTHM: " + hits + " / " + BEATS.length;
            step++;
            beatTimer = new Timer(600, 1);
            beatTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function(te:TimerEvent):void { runNextBeat(); });
            beatTimer.start();
        }

        private function onTimeExpired(e:TimerEvent):void {
            isAwaitingKey=false;
            beatTF.text="TOO SLOW!"; beatTF.textColor=0xFF0000;
            step++;
            beatTimer = new Timer(500, 1);
            beatTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function(te:TimerEvent):void { runNextBeat(); });
            beatTimer.start();
        }

        private function endFusion():void {
            stopGame();
            if (hits > bestScore) bestScore = hits;
            highTF.text = "BEST: " + bestScore + " / 6";

            if (hits >= 5) {
                statusTF.text = "FUSION SUCCESS!"; beatTF.text = "GOGETA UNLOCKED!";
                statusTF.textColor = 0x00FF41; beatTF.textColor = 0xFFD700;
                p1.visible = false;
                p2.visible = false;
                p3.visible = true; // Show Gogeta!
            } else if (hits >= 3) {
                statusTF.text = "ALMOST!"; beatTF.text = "VEKU...";
                p1.visible = false; p2.visible = false; p4.visible = true;
            } else {
                statusTF.text = "FUSION FAILED!"; beatTF.text = "PRACTICE MORE!";
                statusTF.textColor = 0xFF0000; beatTF.textColor = 0xFF0000;
                p1.visible = false; p2.visible = false; p4.visible = true;
            }
            scoreTF.text = "FINAL SCORE: " + hits + " / " + BEATS.length;

            // Restart button
            var rb:Sprite = new Sprite();
            rb.graphics.beginFill(0x003300); rb.graphics.drawRect(0,0,180,36); rb.graphics.endFill();
            rb.graphics.lineStyle(1,0x00ff41,0.6); rb.graphics.drawRect(0,0,180,36);
            var rtf:TextField = new TextField();
            var fmt2:TextFormat = new TextFormat("Orbitron",12,0x00FF41,true);
            fmt2.align = "center";
            rtf.defaultTextFormat = fmt2; rtf.embedFonts = false;
            rtf.text="PLAY AGAIN"; rtf.width=180; rtf.y=9; rtf.selectable=false; rtf.mouseEnabled=false;
            rb.addChild(rtf);
            rb.x = 550; rb.y = 560; rb.buttonMode=true; rb.mouseChildren=false;
            rb.addEventListener(MouseEvent.CLICK, function(me:MouseEvent):void {
                removeChild(rb); startFusion();
            });
            addChild(rb);
        }
    }
}












