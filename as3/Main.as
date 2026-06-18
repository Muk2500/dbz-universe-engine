/**
 * Main Application Controller (Monolithic State Machine)
 * 
 * Handles core application initialization, global state management, 
 * asynchronous media streaming (NetStream), and multi-channel audio crossfading.
 * Serves as the central hub for module instantiation and garbage collection.
 */
package {
    import flash.system.fscommand;
    import flash.display.*;
    import flash.events.*;
    import flash.filters.*;
    import flash.geom.*;
    import flash.net.URLRequest;
    import flash.utils.Timer;
    import flash.text.*;
    import flash.media.Sound;
    import flash.media.SoundChannel;
    import flash.media.SoundTransform;
    import flash.ui.Mouse;
    import flash.net.NetConnection;
    import flash.net.NetStream;
    import flash.media.Video;
    import flash.utils.getDefinitionByName;
    import ui.CharacterModal;
    import games.FusionDance;
    import games.ZRunner;

    public class Main extends Sprite {

        private var bgLayer:Sprite;
        private var contentLayer:Sprite;
        private var hudLayer:Sprite;
        private var transLayer:Sprite; // for screen transition flash
        private var cursorLayer:Sprite;

        // BGM System
        private var bgmChannel:SoundChannel;
        private var currentBgmUrl:String = "";
        private var bgmTransform:SoundTransform = new SoundTransform(0.5);
        private var bgmFadeTimer:Timer;

        // Manga Physics Toggle
        private var useSmoothScrolling:Boolean = true;

        private var scnHome:Sprite;
        private var scnManga:Sprite;
        private var scnGames:Sprite;
        private var scnRoster:Sprite;

        private var plTF:TextField;
        private var plTarget:int = 7504;
        private var plFlicker:Timer;
        private var clockTimer:Timer;
        private var clockTF:TextField;
        private var cursorDot:Sprite;

        private var mangaPages:Array = [];
        private var mangaIndex:int = 0;
        private var mangaLoader:Loader;
        private var mangaImg:Sprite;
        private var mangaScrollContainer:Sprite;
        private var mangaStatus:TextField;
        private var ascendBtnInstance:Sprite;
        private var activeChapterIdx:int = 0;
        
        // Manga Chapters Setup
        private var chapterData:Array = [
            { num: 317, pages: 17, folder: "manga/317" },
            { num: 318, pages: 16, folder: "manga/318" },
            { num: 319, pages: 15, folder: "manga/319" },
            { num: 320, pages: 14, folder: "manga/320" },
            { num: 321, pages: 15, folder: "manga/321" },
            { num: 322, pages: 15, folder: "manga/322" },
            { num: 323, pages: 17, folder: "manga/323" },
            { num: 324, pages: 15, folder: "manga/324" },
            { num: 325, pages: 15, folder: "manga/325" },
            { num: 326, pages: 15, folder: "manga/326" },
            { num: 327, pages: 13, folder: "manga/327" }
        ];
        
        private var mangaScrollY:Number = 0;
        private var mangaScrollTarget:Number = 0;
        private var mangaScrollVelocity:Number = 0;

        private var hoverBeep:Sound;
        private var clickBeep:Sound;
        private var beepChannel:SoundChannel;
        private var clickChannel:SoundChannel;
        private var activeGame:Sprite;
        
        private var mangaTotalHeight:Number = 0;
        private var gameUI:Sprite;
        private var particles:Array = [];

        public function Main() {
            if (stage) init();
            else addEventListener(Event.ADDED_TO_STAGE, init);
        }

        private function init(e:Event = null):void {
            removeEventListener(Event.ADDED_TO_STAGE, init);

            loadChapter(0);

            // Play background music if it exists in the library
            try {
                var bgmClass:Class = getDefinitionByName("BGMusic") as Class;
                var bgm:Sound = new bgmClass() as Sound;
                bgm.play(0, 9999);
            } catch(e:Error) {}

            stage.scaleMode = StageScaleMode.SHOW_ALL;
            stage.quality = "best"; // Forces high-fidelity anti-aliasing to stop pixelation
            fscommand("fullscreen", "true");
            fscommand("showmenu", "false");
            stage.frameRate = 60;
            
            // Force Fullscreen dynamically on the very first mouse click
            stage.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
                try {
                    if (stage.displayState != StageDisplayState.FULL_SCREEN_INTERACTIVE) {
                        stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
                    }
                } catch(err:Error) {}
            });

            // Wipe any FLA timeline objects
            while (numChildren > 0) {
                var c:DisplayObject = getChildAt(0);
                if (c is InteractiveObject) InteractiveObject(c).mouseEnabled = false;
                if (c is DisplayObjectContainer) DisplayObjectContainer(c).mouseChildren = false;
                removeChildAt(0);
            }

            bgLayer = new Sprite();
            bgLayer.mouseEnabled  = false;
            bgLayer.mouseChildren = false;
            addChild(bgLayer);

            contentLayer = new Sprite();
            contentLayer.mouseEnabled  = false; // containers pass events through
            addChild(contentLayer);

            hudLayer = new Sprite();
            hudLayer.mouseEnabled  = false; // cursor overlay must NOT steal clicks
            addChild(hudLayer);

            transLayer = new Sprite(); // full-screen flash on transition
            transLayer.mouseEnabled  = false;
            transLayer.mouseChildren = false;
            addChild(transLayer);
            
            cursorLayer = new Sprite();
            cursorLayer.mouseEnabled = false;
            cursorLayer.mouseChildren = false;
            addChild(cursorLayer);

            setupPersistentUI();

            stage.addEventListener(Event.RESIZE, onStageResize);
            onStageResize();

            showScreen("SPLASH");
            stage.addEventListener(KeyboardEvent.KEY_DOWN, onKey);
        }

// ----------------------------------------------------------------------------------
        //  SOUND SYNTHESIS
// ----------------------------------------------------------------------------------
        private function makeTone(freq:Number, vol:Number, punchy:Boolean = false):Sound {
            var s:Sound = new Sound();
            var fq:Number = freq;
            var vl:Number = vol;
            var isFinished:Boolean = false;
            s.addEventListener(SampleDataEvent.SAMPLE_DATA, function(ev:SampleDataEvent):void {
                if (isFinished) return;
                var written:int = 0;
                for (var i:int = 0; i < 4096; i++) {
                    var t:Number = (ev.position + i) / 44100;
                    var fade:Number = 1 - t * (punchy ? 15 : (fq > 600 ? 20 : 14));
                    if (fade <= 0) {
                        isFinished = true;
                        break;
                    }
                    var raw:Number = punchy ? (Math.random() - 0.5) * 2 : Math.sin(t * Math.PI * 2 * fq);
                    var wave:Number = punchy ? raw : ((fq > 600) ? (raw > 0 ? 1 : -1) * 0.45 : raw);
                    ev.data.writeFloat(wave * vl * fade);
                    ev.data.writeFloat(wave * vl * fade);
                    written++;
                }
            });
            return s;
        }

        private function playHover():void {
            try { if (beepChannel) beepChannel.stop(); beepChannel = makeTone(880, 0.03).play(); } catch(err:Error){}
        }
        private function playClick():void {
            try { if (clickChannel) clickChannel.stop(); clickChannel = makeTone(200, 0.3, true).play();  } catch(err:Error){}
        }

        private function playBGM(filename:String, targetVol:Number = 0.5):void {
            if (currentBgmUrl == filename) return;
            currentBgmUrl = filename;
            
            var oldChannel:SoundChannel = bgmChannel;
            var oldTransform:SoundTransform = bgmTransform;
            bgmTransform = new SoundTransform(0); // Start new track at 0 volume
            
            var attemptPaths:Array = ["../assets/audio/" + filename, "assets/audio/" + filename, "../../assets/audio/" + filename];
            var pathIdx:int = 0;
            var currentSound:Sound = null;
            
            var tryNext:Function = function():void {
                if (pathIdx >= attemptPaths.length) {
                    // Failed to load new track, just fade out old track
                    if (bgmFadeTimer) { bgmFadeTimer.stop(); }
                    bgmFadeTimer = new Timer(50);
                    bgmFadeTimer.addEventListener(TimerEvent.TIMER, function(e:Event):void {
                        if (oldChannel) {
                            oldTransform.volume -= 0.05;
                            if (oldTransform.volume <= 0) {
                                oldChannel.stop(); oldChannel = null; bgmFadeTimer.stop();
                            } else {
                                oldChannel.soundTransform = oldTransform;
                            }
                        }
                    });
                    bgmFadeTimer.start();
                    return;
                }
                
                currentSound = new Sound(new URLRequest(attemptPaths[pathIdx]));
                pathIdx++;
                
                bgmChannel = currentSound.play(0, 9999, bgmTransform);
                
                // Crossfade Logic
                if (bgmFadeTimer) { bgmFadeTimer.stop(); }
                bgmFadeTimer = new Timer(50);
                bgmFadeTimer.addEventListener(TimerEvent.TIMER, function(e:Event):void {
                    var isFading:Boolean = false;
                    
                    if (oldChannel) {
                        oldTransform.volume -= 0.05;
                        if (oldTransform.volume <= 0) {
                            oldTransform.volume = 0;
                            oldChannel.stop();
                            oldChannel = null;
                        } else {
                            oldChannel.soundTransform = oldTransform;
                            isFading = true;
                        }
                    }
                    
                    if (bgmChannel && bgmTransform.volume < targetVol) {
                        bgmTransform.volume += 0.05;
                        if (bgmTransform.volume > targetVol) bgmTransform.volume = targetVol;
                        bgmChannel.soundTransform = bgmTransform;
                        isFading = true;
                    }
                    
                    if (!isFading) bgmFadeTimer.stop();
                });
                bgmFadeTimer.start();
                
                currentSound.addEventListener(IOErrorEvent.IO_ERROR, function(e:Event):void {
                    if (bgmChannel) bgmChannel.stop();
                    tryNext();
                });
            };
            tryNext();
        }

        public function setBgmVolume(vol:Number):void {
            if (bgmFadeTimer) bgmFadeTimer.stop(); // Stop fading if abruptly overridden (e.g. for video Climax)
            if (bgmChannel) {
                bgmTransform.volume = vol;
                bgmChannel.soundTransform = bgmTransform;
            }
        }

// ----------------------------------------------------------------------------------
        //  STAGE CENTERING
// ----------------------------------------------------------------------------------
        private function onStageResize(e:Event = null):void {
            var sw:Number = 1280;
            var sh:Number = 720;
            var cx:Number = 0;
            var cy:Number = 0;
            contentLayer.x = cx; contentLayer.y = cy;
            hudLayer.x = cx;     hudLayer.y     = cy;
            cursorLayer.x = cx;  cursorLayer.y  = cy;
        }

// ----------------------------------------------------------------------------------
        //  CHAPTER LOAD
// ----------------------------------------------------------------------------------
        private function loadChapter(idx:int):void {
            activeChapterIdx = idx;
            mangaPages = []; mangaIndex = 0;
            var ch:Object = chapterData[activeChapterIdx];
            for (var i:int = 1; i <= ch.pages; i++) {
                mangaPages.push(ch.folder + "/" + i + ".jpg");
            }
        }

// ----------------------------------------------------------------------------------
        //  PERSISTENT HUD
// ----------------------------------------------------------------------------------
        private function setupPersistentUI():void {
            // ---- Scouter POV Overlay ----
            var scouterHUD:Sprite = new Sprite();
            scouterHUD.mouseEnabled = false;
            scouterHUD.mouseChildren = false;
            hudLayer.addChildAt(scouterHUD, 0);

            // Faint green tint
            scouterHUD.graphics.beginFill(0x00FF41, 0.03);
            scouterHUD.graphics.drawRect(-500, -500, 3000, 2000);
            scouterHUD.graphics.endFill();

            // Corner brackets
            scouterHUD.graphics.lineStyle(4, 0x00FF41, 0.4);
            // Top Left
            scouterHUD.graphics.moveTo(50, 80); scouterHUD.graphics.lineTo(50, 50); scouterHUD.graphics.lineTo(80, 50);
            // Top Right
            scouterHUD.graphics.moveTo(1230, 80); scouterHUD.graphics.lineTo(1230, 50); scouterHUD.graphics.lineTo(1200, 50);
            // Bottom Left
            scouterHUD.graphics.moveTo(50, 640); scouterHUD.graphics.lineTo(50, 670); scouterHUD.graphics.lineTo(80, 670);
            // Bottom Right
            scouterHUD.graphics.moveTo(1230, 640); scouterHUD.graphics.lineTo(1230, 670); scouterHUD.graphics.lineTo(1200, 670);

            // Scouter diagnostics
            var alienText:TextField = mkTF("SYS.RDY\nINIT 0\n0x9F3\n\n\nTRK", 20, 300, 100, 200, 0x00FF41, 11, false, "left", "Orbitron");
            alienText.alpha = 0.5;
            scouterHUD.addChild(alienText);
            
            var scanTimer:Timer = new Timer(250);
            scanTimer.addEventListener(TimerEvent.TIMER, function(te:Event):void {
                if (Math.random() > 0.4) {
                    alienText.text = "SYS.ACTV\n" + int(Math.random()*99) + "-Z\n" + int(Math.random()*9999) + "\nOP.7\n\n\nTRK\n\n" + (Math.random()>0.8?"\u25A0":"");
                }
            });
            scanTimer.start();
            
            var recBox:Sprite = new Sprite();
            recBox.graphics.beginFill(0xFF0000, 0.8);
            recBox.graphics.drawCircle(30, 35, 5);
            recBox.graphics.endFill();
            recBox.filters = [new GlowFilter(0xFF0000, 0.8, 8, 8, 2)];
            scouterHUD.addChild(recBox);
            scouterHUD.addChild(mkTF("REC", 40, 25, 50, 20, 0xFF0000, 16, true, "left", "Orbitron"));
            
            var recTimer:Timer = new Timer(1000);
            recTimer.addEventListener(TimerEvent.TIMER, function(te:Event):void {
                recBox.visible = !recBox.visible;
            });
            recTimer.start();

            // ---- Background ----
            var bg:Shape = new Shape();
            bg.graphics.beginFill(0x0c0c18);
            bg.graphics.drawRect(-2000, -2000, 8000, 8000);
            bg.graphics.endFill();
            bgLayer.addChild(bg);

            // ---- Radar Grid (covers huge area so no gaps on any window size) ----
            var grid:Shape = new Shape();
            grid.graphics.lineStyle(1, 0x1a1a3a, 0.35);
            for (var gx:int = -500; gx < 4000; gx += 40) {
                grid.graphics.moveTo(gx, -500); grid.graphics.lineTo(gx, 3000);
            }
            for (var gy:int = -500; gy < 3000; gy += 40) {
                grid.graphics.moveTo(-500, gy); grid.graphics.lineTo(4000, gy);
            }
            bgLayer.addChild(grid);

            // ---- Nav Bar ----
            var nav:Sprite = new Sprite();
            nav.x = 850; nav.y = 20;
            hudLayer.addChild(nav);
            var navItems:Array = [
                {id:"HOME",   l:"HOME",          x:0,   w:80,  col:0xFFD700},
                {id:"MANGA",  l:"MANGA",          x:90,  w:80, col:0x00BFFF},
                {id:"TRAINING", l:"TRAINING ROOM",x:180, w:120, col:0xcc0000},
                {id:"ROSTER", l:"GALACTIC",       x:310, w:100, col:0x9B30FF}
            ];
            for each (var it:Object in navItems) {
                var nb:Sprite = mkNavBtn(it.l, it.x, 0, it.w, 30, it.col);
                (function(nid:String, b:Sprite):void {
                    b.addEventListener(MouseEvent.CLICK, function(ev:MouseEvent):void {
                        playClick(); doTransition(nid);
                    });
                })(it.id, nb);
                nav.addChild(nb);
            }

            // ---- Power Level Scouter ----
            var hud:Sprite = new Sprite();
            hud.x = 1100; hud.y = 80;
            hud.mouseEnabled = false; hud.mouseChildren = false;
            hudLayer.addChild(hud);
            hud.addChild(mkTF("POWER LEVEL", 0, 0, 150, 20, 0x00ff41, 10, false, "right", "Orbitron"));
            plTF = mkTF("7504", 0, 15, 150, 55, 0xffffff, 44, true, "right", "Orbitron");
            plTF.filters = [new GlowFilter(0xffffff, 0.2, 4, 4, 1)];
            hud.addChild(plTF);
            hud.addChild(mkTF("SCANNING...", 0, 65, 150, 20, 0x00ff41, 8, false, "right", "Orbitron"));
            plFlicker = new Timer(150);
            plFlicker.addEventListener(TimerEvent.TIMER, function(te:Event):void {
                var val:int = 1 + int(Math.random() * 8000); if(Math.random() < 0.1) val = 8000 + int(Math.random() * 1998);
                if (Math.random() < 0.10) val += 500;
                if (Math.random() < 0.03) val = 9001 + int(Math.random() * 500);
                plTF.text = String(val);
                plFlicker.delay = 80 + Math.random() * 300;
            });
            plFlicker.start();

            // ---- Bottom status bar ----
            hudLayer.addChild(mkTF("RACE: SAIYAN / CLASS: Z", 20,  695, 400, 20, 0x00ff41, 10, false, "left",   "Orbitron"));
            hudLayer.addChild(mkTF(":: EARTH-SECTOR-7G ::",  0,  695, 1280,20, 0x00ff41, 10, false, "center", "Orbitron"));
            clockTF = mkTF("00:00:00", 860, 695, 400, 20, 0x00ff41, 10, false, "right", "Orbitron");
            hudLayer.addChild(clockTF);
            clockTimer = new Timer(1000);
            clockTimer.addEventListener(TimerEvent.TIMER, function(e:Event):void {
                var d:Date = new Date();
                var pad:Function = function(n:int):String { return n < 10 ? "0"+n : ""+n; };
                clockTF.text = pad(d.getHours())+":"+pad(d.getMinutes())+":"+pad(d.getSeconds());
            });
            clockTimer.start();

            // ---- Custom Scouter Cursor ----
            Mouse.hide();
            cursorDot = new Sprite();
            cursorDot.mouseEnabled = false; cursorDot.mouseChildren = false;
            cursorDot.graphics.beginFill(0x00FF41);
            cursorDot.graphics.drawCircle(0, 0, 4);
            cursorDot.graphics.endFill();
            cursorDot.graphics.lineStyle(1, 0x00FF41, 0.5);
            cursorDot.graphics.moveTo(-12, 0); cursorDot.graphics.lineTo( 12, 0);
            cursorDot.graphics.moveTo(0, -12); cursorDot.graphics.lineTo(0,  12);
            cursorDot.filters = [new GlowFilter(0x00FF41, 0.7, 10, 10, 2)];
            cursorLayer.addChild(cursorDot);
            stage.addEventListener(Event.ENTER_FRAME, onFrame);

            // ---- Ki Particles & Hand-Animated DragonBalls ----
            var spawnTimer:Timer = new Timer(120);
            spawnTimer.addEventListener(TimerEvent.TIMER, function(e:Event):void {
                if (particles.length > 120) return; // higher cap
                var p:Shape = new Shape();
                var sz:Number = 0.8 + Math.random() * 3.5;
                var kiColors:Array = [0xFFD700, 0xFF8C00, 0x00BFFF, 0xFFFFFF, 0x00FF41];
                var col:uint = kiColors[int(Math.random() * kiColors.length)];
                p.graphics.beginFill(col, 0.9);
                p.graphics.drawCircle(0, 0, sz);
                p.graphics.endFill();
                
                // Spawn across FULL physical window
                var sw:Number = Math.max(stage.stageWidth,  1280);
                var sh_height:Number = Math.max(stage.stageHeight, 720);
                p.x = Math.random() * sw;
                p.y = sh_height + 50;
                bgLayer.addChild(p);
                particles.push({s:p, sp:1.2 + Math.random() * 4.0, dr:(Math.random() * 2.5) - 1.25});
            });
            spawnTimer.start();
        }

        private function onFrame(e:Event):void {
            for (var pi:int = particles.length - 1; pi >= 0; pi--) {
                var pp:Object = particles[pi];
                pp.s.y -= pp.sp;
                pp.s.x += pp.dr;
                pp.s.alpha -= 0.003;
                if (pp.s.y < -20 || pp.s.alpha <= 0) {
                    if (bgLayer.contains(pp.s)) bgLayer.removeChild(pp.s);
                    particles.splice(pi, 1);
                }
            }

            if (mangaScrollContainer) {
                if (useSmoothScrolling) {
                    mangaScrollVelocity += (mangaScrollTarget - mangaScrollY) * 0.08;
                    mangaScrollVelocity *= 0.85; // higher friction = stops faster, less wobble
                    mangaScrollY += mangaScrollVelocity;
                } else {
                    mangaScrollVelocity = 0;
                    mangaScrollY += (mangaScrollTarget - mangaScrollY) * 0.4; // Instant snappy movement
                }
                mangaScrollContainer.y = 110 + mangaScrollY;
                
                // Show ASCEND button only when scrolled down (target < -10)
                if (ascendBtnInstance) ascendBtnInstance.visible = (mangaScrollTarget < -10);
            }
            // Cursor: use local coords of cursorLayer so centering offset doesn't displace it
            cursorDot.x = cursorLayer.mouseX;
            cursorDot.y = cursorLayer.mouseY;
        }

// ----------------------------------------------------------------------------------
        //  SCREEN TRANSITION  (Instant Transmission - fast dark blink)
// ----------------------------------------------------------------------------------
                                private function doTransition(id:String):void {
            try { 
                var SClass:Class = flash.utils.getDefinitionByName("ARC_MENU_SYS_TLP_wav") as Class;
                if (!SClass) SClass = flash.utils.getDefinitionByName("ARC_MENU_SYS_TLP") as Class;
                if(SClass) {
                    var snd:flash.media.Sound = new SClass(); 
                    snd.play(); 
                }
            } catch(err:Error){}
            
            showScreen(id);
        }

// ----------------------------------------------------------------------------------
        //  CONTENT SWITCHER
// ----------------------------------------------------------------------------------
        private function showScreen(id:String):void {
            if (activeGame) clearGame();
            if (hudLayer) hudLayer.visible = (id != "MANGA" && id != "SPLASH"); // Hide HUD on Manga and Splash
            while (contentLayer.numChildren > 0) contentLayer.removeChildAt(0);
            
            // Global BGM Zones
            if (id == "HOME" || id == "ROSTER") {
                playBGM("vegeta_theme.mp3", 0.4);
            } else if (id == "MANGA") {
                playBGM("gohan_angers.mp3", 0.5);
            } else if (id == "TRAINING") {
                playBGM("hyperbolic-time-chamber.mp3", 0.45);
            }
            
            if      (id == "SPLASH") buildSplash();
            else if (id == "HOME")   buildHome();
            else if (id == "MANGA")  buildManga();
            else if (id == "ROSTER") buildRoster();
            else if (id == "TRAINING")  buildGames();
            else if (id == "ANIME")     buildAnimeMenu();
            else if (id == "CREDITS")   buildCredits();
        }

// ----------------------------------------------------------------------------------
        //  SPLASH SCREEN
// ----------------------------------------------------------------------------------
        private function buildSplash():void {
            var scnSplash:Sprite = new Sprite();
            contentLayer.addChild(scnSplash);
            
            var bg:Shape = new Shape();
            bg.graphics.beginFill(0x0c0c18);
            bg.graphics.drawRect(-500, -500, 3000, 2000);
            bg.graphics.endFill();
            scnSplash.addChild(bg);
            
            var aura:Shape = new Shape();
            aura.graphics.beginFill(0xFFD700, 0.4);
            aura.graphics.drawCircle(0, 0, 150);
            aura.graphics.endFill();
            aura.x = 640; aura.y = 180;
            aura.filters = [new GlowFilter(0xFFD700, 0.8, 100, 100, 2), new BlurFilter(40, 40, 2)];
            scnSplash.addChild(aura);
            
            var clickPrompt:TextField = mkTF("CLICK TO BEGIN", 0, 480, 1280, 70, 0x00BFFF, 48, true, "center", "Orbitron");
            clickPrompt.filters = [new GlowFilter(0x00BFFF, 0.6, 20, 20, 2)];
            scnSplash.addChild(clickPrompt);

            var subPrompt:TextField = mkTF("CAPSULE CORP. SECURE TERMINAL // V2.0", 0, 550, 1280, 30, 0x00FF41, 18, true, "center", "Orbitron");
            subPrompt.alpha = 0.7;
            scnSplash.addChild(subPrompt);

            var pulsePhase:Number = 0;
            scnSplash.addEventListener(Event.ENTER_FRAME, function(ev:Event):void {
                if (!scnSplash.parent) return;
                pulsePhase += 0.08;
                clickPrompt.alpha = 0.4 + 0.6 * Math.abs(Math.sin(pulsePhase));
            });
            
            var logoBmp:DisplayObject = null;
            var logoLdr:Loader = new Loader();
            logoLdr.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):void {
                logoBmp = logoLdr.content;
                var tw:Number = 550;
                var r:Number = logoBmp.height / logoBmp.width;
                logoBmp.width = tw; logoBmp.height = tw * r;
                logoBmp.x = (1280 - logoBmp.width) / 2;
                logoBmp.y = -300;
                scnSplash.addChild(logoBmp);
            });
            loadSmart(logoLdr, "DRAGONBALL LOGO.png");
            
            var tick:int = 0;
            var splashFrame:Function = function(ef:Event):void {
                tick++;
                if (logoBmp) logoBmp.y += (115 - logoBmp.y) * 0.1;
                aura.scaleX = aura.scaleY = 1 + Math.sin(tick * 0.05) * 0.2;
                aura.alpha = 0.5 + Math.sin(tick * 0.05) * 0.2;
                clickPrompt.alpha = 0.5 + Math.sin(tick * 0.1) * 0.5;
            };
            scnSplash.addEventListener(Event.ENTER_FRAME, splashFrame);
            
            var isTransitioning:Boolean = false;
            var doSplashTransition:Function = function():void {
                if (isTransitioning) return;
                isTransitioning = true;
                scnSplash.removeEventListener(Event.ENTER_FRAME, splashFrame);
                if (stage) stage.removeEventListener(KeyboardEvent.KEY_DOWN, arguments.callee);
                
                var vanishSound:Sound = makeTone(1200, 0.1);
                vanishSound.play();
                
                var fade:Shape = new Shape();
                fade.graphics.beginFill(0x000000);
                fade.graphics.drawRect(-500,-500,3000,2000);
                fade.graphics.endFill();
                fade.alpha = 0;
                scnSplash.addChild(fade);
                
                var fTick:int = 0;
                scnSplash.addEventListener(Event.ENTER_FRAME, function(fe:Event):void {
                    fTick++;
                    fade.alpha += 0.1;
                    if (fTick == 15) {
                        scnSplash.removeEventListener(Event.ENTER_FRAME, arguments.callee);
                        showScreen("HOME");
                    }
                });
            };
            
            var keyHandler:Function = function(ke:KeyboardEvent):void {
                if (stage) stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyHandler);
                doSplashTransition();
            };
            scnSplash.buttonMode = true;
            scnSplash.addEventListener(MouseEvent.CLICK, function(ce:MouseEvent):void {
                if (stage) stage.removeEventListener(KeyboardEvent.KEY_DOWN, keyHandler);
                doSplashTransition();
            });
            if (stage) stage.addEventListener(KeyboardEvent.KEY_DOWN, keyHandler);
        }

        // ----------------------------------------------------------------------------------
        //  HOME
        // ----------------------------------------------------------------------------------
        private function buildHome():void {
            scnHome = new Sprite();
            contentLayer.addChild(scnHome);

            scnHome.addChild(mkTF(":: EARTH'S SPECIAL FORCES - CLASSIFIED DATABASE ::",
                0, 78, 1280, 30, 0x00ff41, 10, false, "center", "Orbitron"));

            // Spawn large, beautiful DragonBalls as background props
            var numBalls:int = 4 + int(Math.random() * 3);
            for (var b:int = 0; b < numBalls; b++) {
                try {
                    var randNum:int = 1 + int(Math.random() * 7);
                    var DBClass:Class = getDefinitionByName("DragonBall" + randNum) as Class;
                    var db:DisplayObject = new DBClass() as DisplayObject;
                    db.scaleX = db.scaleY = 0.9 + Math.random() * 0.6; // Large
                    db.x = 100 + Math.random() * 1080;
                    db.y = 100 + Math.random() * 500;
                    db.alpha = 0.8;
                    scnHome.addChildAt(db, 0); // Put them behind the logo/text
                } catch(err:Error) {}
            }

            var ldr:Loader = new Loader();
            ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):void {
                var bmp:DisplayObject = ldr.content;
                var tw:Number = 550;
                var r:Number = bmp.height / bmp.width;
                bmp.width = tw; bmp.height = tw * r;
                bmp.x = (1280 - bmp.width) / 2;
                bmp.y = 115;
                scnHome.addChild(bmp);
            });
            ldr.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function(e:Event):void{});
            loadSmart(ldr, "DRAGONBALL LOGO.png");

            scnHome.addChild(mkTF("WELCOME TO THE DBZ UNIVERSE",
                0, 310, 1280, 50, 0xFF4500, 36, true, "center", "Orbitron"));
            scnHome.addChild(mkTF(
                "Enter the universe. Feel the power level. Witness the legend of Earth's mightiest warriors.",
                200, 360, 880, 50, 0x888888, 13, false, "center", "Orbitron"));
                
            // Glassmorphism Menu Backdrop
            var menuBg:Sprite = new Sprite();
            menuBg.graphics.beginFill(0x0c0c18, 0.7);
            menuBg.graphics.lineStyle(2, 0x00BFFF, 0.4);
            menuBg.graphics.drawRoundRect(280, 420, 720, 100, 20, 20);
            menuBg.graphics.endFill();
            menuBg.filters = [new GlowFilter(0x00BFFF, 0.3, 15, 15, 1)];
            scnHome.addChild(menuBg);

            var b1:Sprite = mkBtn("GALACTIC ARCHIVE", 320, 450, 200, 44, 0x111122, 0xFFD700, true, 0xFFD700);
            b1.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
                playClick(); doTransition("ROSTER");
            });
            scnHome.addChild(b1);

            var b2:Sprite = mkBtn("READ MANGA", 560, 450, 160, 44, 0x111122, 0x00BFFF, true, 0x00BFFF);
            b2.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
                playClick(); doTransition("MANGA");
            });
            scnHome.addChild(b2);

            var b3:Sprite = mkBtn("CUTSCENES", 760, 450, 200, 44, 0x111122, 0xFF2020, true, 0xFF2020);
            b3.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
                playClick(); doTransition("ANIME");
            });
            scnHome.addChild(b3);

            // Credits moved to center below menu
            var b4:Sprite = mkBtn("SYSTEM CREDITS", 565, 540, 150, 30, 0x111122, 0x00FF41, true, 0x00FF41);
            b4.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
                playClick(); doTransition("CREDITS");
            });
            var bExit:Sprite = mkBtn("EXIT SYSTEM", 565, 580, 150, 30, 0x111122, 0xFF0000, true, 0xFF0000);
            bExit.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
                playClick(); fscommand("quit", "true");
            });
            scnHome.addChild(bExit);
            scnHome.addChild(b4);
        }

        private function buildAnimeMenu():void {
            var scnAnime:Sprite = new Sprite();
            contentLayer.addChild(scnAnime);

            var title:TextField = mkTF("ANIME ARCHIVE", 0, 60, 1280, 40, 0xFFFFFF, 36, true, "center", "Orbitron");
            scnAnime.addChild(title);

            var vids:Array = [
                {title: "THE LEGEND AWAKENS", sub: "Goku Goes Super Saiyan", file: "Goku goes super saiyan.mp4", y: 150, color: 0xFFD700},
                {title: "A FRIEND FALLS", sub: "Krillin Blows Up", file: "Krillin Blows Up.mp4", y: 280, color: 0xFF4500},
                {title: "YOU FOOL!", sub: "Goku Ends Frieza", file: "Goku ends Frieza.mp4", y: 410, color: 0x00BFFF}
            ];

            for each (var v:Object in vids) {
                var c:Sprite = new Sprite();
                c.y = v.y;
                c.x = 240;
                scnAnime.addChild(c);

                c.graphics.beginFill(0x111122, 0.8);
                c.graphics.lineStyle(2, v.color, 0.5);
                c.graphics.drawRoundRect(0, 0, 800, 100, 20, 20);
                c.graphics.endFill();

                c.addChild(mkTF(v.title, 30, 20, 700, 30, v.color, 24, true, "left", "Orbitron"));
                c.addChild(mkTF(v.sub, 30, 55, 700, 20, 0xAAAAAA, 14, false, "left", "Orbitron"));

                var playBtn:Sprite = mkBtn("PLAY", 630, 30, 120, 40, 0x000000, 0xFFFFFF, true, v.color);
                (function(file:String):void {
                    playBtn.addEventListener(MouseEvent.CLICK, function(e:Event):void {
                        playClick(); playVideoCutscene(file);
                    });
                })(v.file);
                c.addChild(playBtn);
            }
        }

        private function buildCredits():void {
            var scnCred:Sprite = new Sprite();
            contentLayer.addChild(scnCred);

            var title:TextField = mkTF("SYSTEM CREDITS", 0, 100, 1280, 40, 0xFFD700, 36, true, "center", "Orbitron");
            scnCred.addChild(title);

            var roles:Array = [
                {r: "LEAD DEVELOPER", n: "MUHAMMED MUKARUM (TP088794)"},
                {r: "ART ASSETS & SOUNDTRACK", n: "AKIRA TORIYAMA / TOEI ANIMATION"},
                {r: "GALACTIC ROSTER DATABASE", n: "DBZ UNIVERSE FAN WIKI"},
                {r: "COPYRIGHT", n: "© 2026 DBZ UNIVERSE ARCHIVE. ALL RIGHTS RESERVED."}
            ];

            var cy:Number = 220;
            for each (var role:Object in roles) {
                scnCred.addChild(mkTF(role.r, 0, cy, 1280, 20, 0x00BFFF, 14, true, "center", "Orbitron"));
                scnCred.addChild(mkTF(role.n, 0, cy + 25, 1280, 30, 0xFFFFFF, 24, false, "center", "Orbitron"));
                cy += 90;
            }
        }

        private function playVideoCutscene(pick:String):void {
            var vidContainer:Sprite = new Sprite();
            vidContainer.graphics.beginFill(0x000000, 0.95);
            vidContainer.graphics.drawRect(-2000, -2000, 8000, 8000);
            vidContainer.graphics.endFill();
            contentLayer.addChild(vidContainer);

            var nc:NetConnection = new NetConnection();
            nc.connect(null);
            var ns:NetStream = new NetStream(nc);
            
            var attemptPaths:Array = ["../assets/video/" + pick, "assets/video/" + pick, "../../assets/video/" + pick];
            var pathIdx:int = 0;
            
            // Smart Loader & Auto-Closer
            ns.addEventListener(NetStatusEvent.NET_STATUS, function(e:NetStatusEvent):void {
                
                if (e.info.code == "NetStream.Play.StreamNotFound") {
                    pathIdx++;
                    if (pathIdx < attemptPaths.length) {
                        ns.play(attemptPaths[pathIdx]);
                    }
                } else if (e.info.code == "NetStream.Play.Stop" || e.info.code == "NetStream.Play.Failed") {
                    if (vidContainer.parent) vidContainer.parent.removeChild(vidContainer);
                    setBgmVolume(0.5);
                }
            });
            
            var vid:Video = new Video(854, 480); // 16:9 standard def
            vid.attachNetStream(ns);
            vid.x = (1280 - 854) / 2;
            vid.y = (720 - 480) / 2;
            vidContainer.addChild(vid);
            
            var client:Object = new Object();
            client.onMetaData = function(metadata:Object):void {};
            ns.client = client;
            
            var closeBtn:Sprite = mkBtn("X CLOSE VIDEO", 850, 80, 130, 30, 0x000000, 0xFFFFFF, true, 0xFF2020);
            closeBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
                ns.close();
                if (vidContainer.parent) vidContainer.parent.removeChild(vidContainer);
                setBgmVolume(0.5); // Restore BGM volume
            });
            vidContainer.addChild(closeBtn);

            ns.play(attemptPaths[0]);
            setBgmVolume(0.05); // Drop BGM volume for the Climax
        }

        // ----------------------------------------------------------------------------------
        //  MANGA
        // ----------------------------------------------------------------------------------
        private function buildManga():void {
            scnManga = new Sprite();
            contentLayer.addChild(scnManga);
            buildChapterSelect();
        }

        private function buildChapterSelect():void {
            while (scnManga.numChildren > 0) scnManga.removeChildAt(0);
            if (hudLayer) { // Show persistent HUD on chapter select
                hudLayer.visible = true;
                if (mangaStatus) mangaStatus.visible = false;
            }

            var title:TextField = mkTF("SELECT CHAPTER", 0, 60, 1280, 40, 0xFFFFFF, 36, true, "center", "Orbitron");
            var sub:TextField = mkTF(":: MANGA ARCHIVE ::", 0, 100, 1280, 20, 0x00BFFF, 12, false, "center", "Orbitron");
            scnManga.addChild(title);
            scnManga.addChild(sub);

            var scrollContainer:Sprite = new Sprite();
            scnManga.addChild(scrollContainer);

            var cardW:Number = 240;
            var cardH:Number = 110;
            var gapX:Number = 30;
            var gapY:Number = 30;
            var cols:int = 4;
            
            var totalGridW:Number = (cols * cardW) + ((cols - 1) * gapX);
            var startX:Number = (1280 - totalGridW) / 2;
            var startY:Number = 160;

            for (var ci:int = 0; ci < chapterData.length; ci++) {
                (function(idx:int, ch:Object):void {
                    var card:Sprite = new Sprite();
                    
                    var col:int = idx % cols;
                    var row:int = Math.floor(idx / cols);
                    card.x = startX + col * (cardW + gapX); 
                    card.y = startY + row * (cardH + gapY);
                    
                    card.buttonMode = true; card.mouseChildren = false;

                    // Design Philosophy: Glassmorphism / Neon Cyber style
                    var drawBg:Function = function(hover:Boolean):void {
                        card.graphics.clear();
                        if (hover) {
                            card.graphics.beginFill(0x00BFFF, 0.15); // bright blue tint
                            card.graphics.lineStyle(2, 0x00BFFF, 0.9);
                        } else {
                            card.graphics.beginFill(0x0a0a1a, 0.85);
                            card.graphics.lineStyle(1, 0x333355, 0.6);
                        }
                        card.graphics.drawRoundRect(0, 0, cardW, cardH, 12, 12);
                        card.graphics.endFill();
                    };
                    drawBg(false);

                    card.addChild(mkTF("CHAPTER " + ch.num, 20, 15, cardW-40, 18, 0x00ff41, 10, false, "left", "Orbitron"));
                    var titleName:String = ch.name ? ch.name : ("Part " + (idx + 1));
                    card.addChild(mkTF(titleName, 20, 35, cardW-40, 34, 0xffffff, 24, true, "left", "Orbitron"));
                    
                    // Add a tiny decorative line
                    var deco:Shape = new Shape();
                    deco.graphics.beginFill(0x00BFFF);
                    deco.graphics.drawRect(20, 75, 40, 2);
                    deco.graphics.endFill();
                    card.addChild(deco);

                    card.addChild(mkTF("FRIEZA ARC", 20, 85, cardW-40, 18, 0x888888, 9, false, "left", "Orbitron"));

                    card.addEventListener(MouseEvent.ROLL_OVER, function(ev:MouseEvent):void {
                        drawBg(true);
                        card.filters = [new GlowFilter(0x00BFFF, 0.5, 10, 10, 2)];
                        playHover();
                    });
                    card.addEventListener(MouseEvent.ROLL_OUT, function(ev:MouseEvent):void {
                        drawBg(false);
                        card.filters = [];
                    });
                    card.addEventListener(MouseEvent.CLICK, function(ev:MouseEvent):void {
                        playClick(); loadChapter(idx); 
                        if (hudLayer) hudLayer.visible = false; // Hide HUD during reading
                        openReader(chapterData[idx]);
                    });
                    scrollContainer.addChild(card);
                })(ci, chapterData[ci]);
            }
            
            // Mouse Wheel Scrolling for Manga Chapters
            var maxScroll:Number = Math.min(0, 720 - (startY + Math.ceil(chapterData.length / cols) * (cardH + gapY)) - 50);
            stage.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):void {
                if (contentLayer.contains(scnManga)) {
                    scrollContainer.y += e.delta * 20;
                    if (scrollContainer.y > 0) scrollContainer.y = 0;
                    if (scrollContainer.y < maxScroll) scrollContainer.y = maxScroll;
                }
            });
        }

        private function openReader(ch:Object):void {
            while (scnManga.numChildren > 0) scnManga.removeChildAt(0);
            
            // Hide persistent HUD during manga reading for cleaner UI
            if (hudLayer) hudLayer.visible = false;
            
            // Fix keyboard scrolling focus bug
            if (stage) stage.focus = stage;

            // Back button
            var back:Sprite = mkBtn("< CHAPTERS", 30, 78, 140, 34, 0x111122, 0x00BFFF, true, 0x00BFFF);
            back.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
                playClick(); 
                if (hudLayer) hudLayer.visible = true; // restore HUD
                buildChapterSelect();
            });
            scnManga.addChild(back);

            // Prev / Next chapter - moved further right to not overlap title bar
            if (activeChapterIdx > 0) {
                var bChPrev:Sprite = mkBtn("< PREV", 1090, 10, 85, 34, 0x111122, 0xFF8C00, true, 0xFF8C00);
                (function(prevIdx:int):void {
                    bChPrev.addEventListener(MouseEvent.CLICK, function(ev:MouseEvent):void {
                        playClick(); loadChapter(prevIdx); openReader(chapterData[prevIdx]);
                    });
                })(activeChapterIdx - 1);
                scnManga.addChild(bChPrev);
            }
            if (activeChapterIdx < chapterData.length - 1) {
                var bChNext:Sprite = mkBtn("NEXT >", 1180, 10, 85, 34, 0x111122, 0xFFD700, true, 0xFFD700);
                (function(nextIdx:int):void {
                    bChNext.addEventListener(MouseEvent.CLICK, function(ev:MouseEvent):void {
                        playClick(); loadChapter(nextIdx); openReader(chapterData[nextIdx]);
                    });
                })(activeChapterIdx + 1);
                scnManga.addChild(bChNext);
            }
            // Toggle Physics Scrolling Button
            var bPhysics:Sprite = mkBtn("SMOOTH SCROLL: ON", 1090, 675, 175, 34, 0x111122, 0x00FF41, true, 0x00FF41);
            bPhysics.addEventListener(MouseEvent.CLICK, function(ev:MouseEvent):void {
                playClick();
                useSmoothScrolling = !useSmoothScrolling;
                var tf:TextField = bPhysics.getChildAt(0) as TextField;
                if (useSmoothScrolling) {
                    tf.text = "SMOOTH SCROLL: ON";
                    tf.textColor = 0x00FF41;
                    bPhysics.filters = [new GlowFilter(0x00FF41, 0.4, 6, 6, 2)];
                } else {
                    tf.text = "SCROLLING: SNAPPY";
                    tf.textColor = 0x888888;
                    bPhysics.filters = [];
                }
            });
            scnManga.addChild(bPhysics);

            // Chapter title bar
            var tBar:Sprite = new Sprite();
            tBar.graphics.beginFill(0x111122, 0.5); tBar.graphics.lineStyle(0);
            tBar.graphics.drawRect(0, 0, 880, 34); tBar.graphics.endFill();
            tBar.graphics.beginFill(0xFF8C00); tBar.graphics.drawRect(0, 0, 3, 34); tBar.graphics.endFill();
            tBar.x = 190; tBar.y = 10;
            tBar.addChild(mkTF("FRIEZA ARC", 12, 7, 90, 20, 0xFF8C00, 9, false, "left", "Orbitron"));
            tBar.addChild(mkTF("CHAPTER " + ch.num + (ch.name ? ": " + ch.name : ""), 108, 6, 600, 22, 0xffffff, 16, true, "left", "Orbitron"));
            scnManga.addChild(tBar);

            // Mask for clipping - max height to utilize screen space
            var msk:Shape = new Shape();
            msk.graphics.beginFill(0xFF0000);
            msk.graphics.drawRect(190, 50, 880, 660);
            msk.graphics.endFill();
            scnManga.addChild(msk);
            
            // Scroll container inside mask
            mangaScrollContainer = new Sprite();
            mangaScrollContainer.x = 190;
            mangaScrollContainer.y = 50;
            mangaScrollContainer.mask = msk;
            scnManga.addChild(mangaScrollContainer);
            
            // Manga viewer area
            mangaImg = new Sprite();
            mangaScrollContainer.addChild(mangaImg);

            // Mouse-wheel smooth scroll
            mangaScrollY = 0;
            mangaScrollTarget = 0;
            mangaScrollVelocity = 0;
            
            ascendBtnInstance = mkBtn("ASCEND", 1105, 330, 120, 38, 0x111122, 0xFF4500, true, 0xFF4500);
            ascendBtnInstance.visible = false;
            scnManga.addChild(ascendBtnInstance);
            ascendBtnInstance.addEventListener(MouseEvent.CLICK, function(ev:MouseEvent):void {
                playClick();
                
                // Create visual DragonBall effect
                var orb:Shape = new Shape();
                orb.graphics.beginFill(0xFF8C00);
                orb.graphics.drawCircle(0, 0, 16);
                orb.graphics.endFill();
                orb.filters = [new GlowFilter(0xFFD700, 1, 20, 20, 2)];
                orb.x = 640; // center
                orb.y = 680; // bottom of panel
                scnManga.addChild(orb);
                
                // Shoot up + scroll to top simultaneously
                var orb_timer:Timer = new Timer(16, 30);
                var orb_step:int = 0;
                orb_timer.addEventListener(TimerEvent.TIMER, function(te:Event):void {
                    orb_step++;
                    var progress:Number = orb_step / 30;
                    
                    // Easing: ease-in (slow start, fast finish)
                    var easeProgress:Number = progress * progress;
                    
                    // Orb flies from bottom to top
                    orb.y = 680 - (easeProgress * 620);
                    orb.alpha = 1 - (progress * 0.3);
                    
                    // Scroll also animates up
                    var easeOut:Number = 1 - Math.pow(1 - progress, 3);
                    mangaScrollTarget = -mangaScrollY * (1 - easeOut);
                });
                orb_timer.addEventListener(TimerEvent.TIMER_COMPLETE, function(te:Event):void {
                    mangaScrollTarget = 0;
                    ascendBtnInstance.visible = false;
                    if (scnManga.contains(orb)) scnManga.removeChild(orb);
                });
                orb_timer.start();
            });

            scnManga.addEventListener(MouseEvent.MOUSE_WHEEL, function(ev:MouseEvent):void {
                mangaScrollTarget -= ev.delta * 18; 
                var maxScroll:Number = Math.max(0, mangaTotalHeight - 660);
                if (mangaScrollTarget > 0) mangaScrollTarget = 0;
                if (mangaScrollTarget < -maxScroll) mangaScrollTarget = -maxScroll;
            });

            mangaStatus = mkTF("", 0, 685, 1280, 24, 0x00ff41, 11, true, "center", "Orbitron");
            // Visible during loading, will fade out when done
            scnManga.addChild(mangaStatus);

            loadMangaPage();
        }

        private function loadMangaPage():void {
            while (mangaImg.numChildren > 0) mangaImg.removeChildAt(0);
            mangaScrollY = 0;
            mangaScrollTarget = 0;
            mangaScrollVelocity = 0;
            mangaTotalHeight = 0;
            if (ascendBtnInstance) ascendBtnInstance.visible = false;
            if (mangaStatus) {
                mangaStatus.visible = true;
                mangaStatus.alpha = 1;
            }
            
            var currentY:Number = 0;
            var pIdx:int = 0;
            
            mangaStatus.text = "LOADING CHAPTER...";
            
            function loadNextInStack():void {
                if (pIdx >= mangaPages.length) {
                    mangaStatus.text = "CHAPTER LOADED: " + mangaPages.length + " PAGES";
                    var fadeT:Timer = new Timer(50, 20);
                    fadeT.addEventListener(TimerEvent.TIMER, function(e:Event):void { mangaStatus.alpha -= 0.05; });
                    fadeT.addEventListener(TimerEvent.TIMER_COMPLETE, function(e:Event):void { mangaStatus.visible = false; mangaStatus.alpha = 1; });
                    fadeT.start();
                    return;
                }
                var path:String = mangaPages[pIdx];
                
                var processImage:Function = function(ldrRef:Loader):void {
                    var img:DisplayObject = ldrRef.content;
                    if (img is flash.display.Bitmap) {
                        (img as flash.display.Bitmap).smoothing = true; // Essential for crisp manga text!
                    }
                    var scaleW:Number = 880 / img.width;
                    img.width *= scaleW;
                    img.height *= scaleW;
                    img.x = 0;
                    img.y = currentY;
                    mangaImg.addChild(img);
                    
                    currentY += img.height + 10;
                    mangaTotalHeight = currentY;
                    pIdx++;
                    mangaStatus.text = "LOADING: PAGE " + pIdx + " / " + mangaPages.length;
                    
                    if (mangaScrollTarget < -(Math.max(0, mangaTotalHeight - 660))) {
                        mangaScrollTarget = -(Math.max(0, mangaTotalHeight - 660));
                    }
                    
                    loadNextInStack();
                };
                
                var ldr1:Loader = new Loader();
                
                var success1:Function = function(e:Event):void {
                    ldr1.contentLoaderInfo.removeEventListener(Event.COMPLETE, success1);
                    processImage(ldr1);
                };
                
                var error1:Function = function(e:IOErrorEvent):void {
                    ldr1.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, error1);
                    ldr1.contentLoaderInfo.removeEventListener(Event.COMPLETE, success1);
                    
                    var ldr2:Loader = new Loader();
                    
                    var success2:Function = function(e2:Event):void {
                        ldr2.contentLoaderInfo.removeEventListener(Event.COMPLETE, success2);
                        processImage(ldr2);
                    };
                    
                    var error2:Function = function(e3:IOErrorEvent):void {
                        ldr2.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, error2);
                        ldr2.contentLoaderInfo.removeEventListener(Event.COMPLETE, success2);
                        pIdx++;
                        loadNextInStack(); // completely missing, skip it
                    };
                    
                    ldr2.contentLoaderInfo.addEventListener(Event.COMPLETE, success2);
                    ldr2.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, error2);
                    try { ldr2.load(new URLRequest("../" + path)); } catch(err:Error) { error2(null); }
                };

                ldr1.contentLoaderInfo.addEventListener(Event.COMPLETE, success1);
                ldr1.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, error1);
                try { ldr1.load(new URLRequest(path)); } catch(err:Error) { error1(null); }
            }
            
            loadNextInStack();
        }

        // ----------------------------------------------------------------------------------
        //  ROSTER
        // ----------------------------------------------------------------------------------
        private function buildRoster():void {
            scnRoster = new Sprite();
            contentLayer.addChild(scnRoster);

            scnRoster.addChild(mkTF(":: CLASSIFIED DATABASE ::",
                0, 60, 1280, 30, 0x00ff41, 10, false, "center", "Orbitron"));
            scnRoster.addChild(mkTF("GALACTIC ARCHIVE",
                0, 75, 1280, 60, 0xffffff, 52, true, "center", "Orbitron"));

            var chars:Array = [
    {id:"goku",    name:"SON GOKU",    race:"SAIYAN",      color:0xFF8C00, img:"goku/GOKU BASEcover image.png",
     desc:"The Saiyan raised on Earth who became the universe's greatest protector. Driven by an insatiable desire to push his limits, Goku transforms his body and soul to overcome any foe.",
     stats:[1500000, 1500000, 1500000, 1500000],
     forms: [
        {name:"BASE",       powerLevel:"3,000,000",             desc:"The calm before the storm. Even in base form, Goku's mastery of martial arts is unparalleled.", intel:"Target is in a state of high-efficiency energy conservation. No wasted ki. Tactical Analysis: Target is likely testing your capabilities. He is highly reactive and focused on defense. Warning: Target is hiding his true ceiling.", img:"goku/GOKU BASEcover image.png"},
        {name:"KAIOKEN X20",powerLevel:"60,000,000",            desc:"Pushing his body to the absolute breaking point. The crimson aura of the Kaioken multiplies his power, but at a massive physical cost.", intel:"Massive heart rate and blood pressure spikes detected. Target is rapidly multiplying his combat power at the cost of severe physiological damage. Tactical Advice: Evade and outlast. His body will tear itself apart if this continues.", img:"goku/goku kaioken.png"},
        {name:"SSJ1",       powerLevel:"150,000,000",           desc:"The legend brought to life. Awakened by pure rage, the golden warrior emerges to end Frieza's reign of terror.", intel:"Extreme emotional surge detected. Power level has multiplied by 50x. Ki signature is turbulent and fueled by anger. Combat Style: Aggressive and overwhelming.", img:"goku/gokussj1.png"},
        {name:"SSJ2",       powerLevel:"300,000,000",           desc:"The sparks of true power. Surpassing the original transformation, this form is defined by lightning-fast movements and crackling electricity.", intel:"Electrical discharges detected in the aura. Target's speed has surpassed the scouter's standard refresh rate. Combat Style: Precision striking. He is twice as strong as the standard Super Saiyan, with zero loss in stamina.", img:"goku/gokussj2.png"},
        {name:"SSJ3",       powerLevel:"1,200,000,000",         desc:"The pinnacle of Z-era power. A transformation so intense it can be felt across the universe, though it drains energy rapidly.", intel:"Ki signature is visible from orbit. Target has reached the absolute limit of Saiyan biology. Warning: Target is leaking massive amounts of energy. Tactical Advice: Defensive maneuvers only. If you survive for 5 minutes, the target will likely revert to base form due to exhaustion.", img:"goku/gokussj3.png"},
        {name:"SSJ4",       powerLevel:"Unknown / Primal Might", desc:"The ultimate union of Saiyan and Great Ape. A primal transformation that brings Goku back to his roots with devastating savage strength.", intel:"ANOMALY: Target has fused Primal Great Ape instinct with Super Saiyan control. Ki signature is 'dense' and 'heavy.' Combat Style: Savage and relentless. Warning: Conventional energy attacks are being absorbed or deflected. Target is an Apex Predator.", img:"goku/gokussj4.png"},
        {name:"SSJ GOD",    powerLevel:"500,000,000,000",        desc:"The legend beyond legends. By harnessing the power of six righteous Saiyans, Goku enters the realm of the Gods. This form provides a massive speed boost and the ability to sense divine ki.", intel:"KI SIGNATURE GONE. Scouter cannot detect divine ki. Analysis: Target has entered a higher dimension of power. Combat Analysis: He is 'faster than instant.' You aren't fighting a man; you are fighting a force of nature.", img:"goku/gokussjgod.png"},
        {name:"SSJ BLUE",   powerLevel:"5,000,000,000,000",      desc:"A Super Saiyan surmounting the power of a God. This form combines godly ki with explosive Saiyan energy.", intel:"Perfect Ki Control detected. The target has combined Godly power with the Super Saiyan transformation. Analysis: Zero energy leakage. Every strike is delivered with 100% efficiency. Survival Probability: Error... Calculation impossible.", img:"goku/gokussjblue.png"},
        {name:"UI MASTERED",powerLevel:"Infinite / Apex",        desc:"The state of the Gods. The body reacts without thought, making Goku nearly untouchable as he nears the peak of martial perfection.", img:"goku/gokuUI.png"}
     ]},
    {id:"vegeta",  name:"VEGETA",  race:"SAIYAN",      color:0xFFFF00, img:"vegeta/vegeta.png",
     desc:"The Prince of all Saiyans and Goku's eternal rival. Driven by a burning desire to reclaim his throne as the strongest in the universe, Vegeta's power is fueled by pure, unyielding pride and a relentless work ethic.",
     stats:[1450000, 1480000, 1400000, 1450000],
     forms: [
         {name:"BASE",       powerLevel:"2,800,000",          desc:"The calm exterior hiding a raging inferno. Vegeta's base power is honed through agonizing gravity training.", intel:"Target is highly disciplined. Fighting stance has no openings. Do not engage in hand-to-hand combat.", img:"vegeta/vegeta.png"},
         {name:"SSJ1",       powerLevel:"150,000,000",        desc:"The legend realized. Vegeta unlocks the Super Saiyan form through sheer, unadulterated self-loathing.", intel:"Massive emotional surge detected. Target's speed and power have multiplied fifty-fold.", img:"vegeta/vegetassj1.png"},
         {name:"MAJIN",      powerLevel:"3,000,000,000",      desc:"The Prince of Destruction returns. By allowing Babidi to unlock his latent malice, Vegeta's power and ruthlessness skyrocket.", intel:"WARNING: MALICE DETECTED. Target's ki is toxic and erratic. He no longer cares about collateral damage. Lethal force authorized.", img:"vegeta/majin_vegeta_ssj2.png"},
         {name:"SSJ GOD",    powerLevel:"500,000,000,000",      desc:"The blazing crimson aura of divine power. Vegeta achieves the realm of Gods through sheer force of will and intense training.", intel:"WARNING: KI SIGNATURE VANISHED. Target is using Divine Ki. Extreme speed and precision detected.", img:"vegeta/super_saiyan_god_vegeta.png"},
         {name:"SSJ BLUE",   powerLevel:"50,000,000,000,000",   desc:"The pinnacle of divine control. A form that pushes past the limits of God Ki into a blinding blue evolution.", intel:"Target's Ki is perfectly contained. Lethality has increased by 1000%. Do not engage.", img:"vegeta/vegeta_ssj_blue_evolution.png"},
         {name:"ULTRA EGO",  powerLevel:"Infinite / Destruction", desc:"The power of a God of Destruction. Damage only fuels his power, making him a terrifying and unstoppable force.", intel:"ANOMALY: Target's power increases exponentially upon receiving damage. Tactical Advice: Flee. Do not attack. Engaging will only make him stronger.", img:"vegeta/vegeta ultra ego.png"}
     ]},
    {id:"gohan",   name:"SON GOHAN",   race:"HALF-SAIYAN", color:0xFFFFFF, img:"gohan/gohan.png",
     desc:"A gentle soul with a hidden reservoir of infinite potential. When his loved ones are in danger, Gohan's dormant power explodes in a display of raw, overwhelming force.",
     stats:[1200000, 1200000, 1150000, 1100000],
     forms: [
         {name:"BASE",       powerLevel:"1,500,000",          desc:"A kind scholar who hides a warrior's spirit.", img:"gohan/gohan.png"},
         {name:"SSJ1",       powerLevel:"75,000,000",         desc:"The first glimpse of the sleeping giant. When Gohan embraces the golden aura of the Super Saiyan, his scholarly nature vanishes, replaced by a warrior's instinct that surpasses even his father's.", intel:"Hidden potential is leaking into the main Ki stream. Target's emotional volatility is off the charts. Tactical Advice: Strike before he reaches the 'Snap' point. If his aura begins to crackle with electricity, the battle is effectively over. Verdict: VOLATILE / HIGH GROWTH POTENTIAL.", img:"gohan/gohan ssj.png"},
         {name:"SSJ2",       powerLevel:"1,200,000,000",      desc:"The moment a boy became a savior. Gohan's silent rage creates a power that even Cell feared.", img:"gohan/gohan ssj2.png"},
         {name:"ULTIMATE",   powerLevel:"35,000,000,000",     desc:"Potential fully unleashed by the Old Kai. No longer needing golden hair, Gohan fights with the full weight of his latent ability.", intel:"Potential fully unlocked. Target no longer requires transformations to access his peak power. Combat Analysis: Target is eerily calm. He possesses the arrogance of a Saiyan but the tactical mind of a scholar. Note: He is looking for a 'perfect' victory. One mistake will be your last.", img:"gohan/gohan ult.png"},
         {name:"BEAST",      powerLevel:"Unquantifiable / Apex", desc:"The primal awakening. A new form born of a snap in Gohan's psyche, surpassing all previous limits of Saiyan evolution.", img:"gohan/Gohan-Beast.png"}
     ]},
    {id:"piccolo", name:"PICCOLO", race:"NAMEKIAN",    color:0x00FF00, img:"piccolo/piccolo.png",
     desc:"The brilliant strategist and former Demon King. Through meditation and fusion with his Namekian brothers, Piccolo has remained one of the few non-Saiyans capable of challenging the gods.",
     stats:[80000000, 75000000, 95000000, 90000000],
     forms: [
         {name:"ULTIMATE",   powerLevel:"800,000,000",        desc:"The Nameless Namekian reborn. By reuniting with Kami, Piccolo gains the wisdom of a God and the power to match a Super Saiyan.", img:"piccolo_fused.png"}
     ]},
    {id:"krillin", name:"KRILLIN", race:"EARTHLING",   color:0xFF9900, img:"krillin/krillin.png",
     desc:"Goku's lifelong best friend and the strongest Earthling to ever live. Though outclassed in raw power by Saiyans, Krillin's mastery of the Destructo-Disc and his tactical brilliance make him a vital ally in any cosmic battle.",
     stats:[50000, 50000, 80000, 75000],
     forms: [
         {name:"BASE",       powerLevel:"75,000",             desc:"The Strongest Human.", intel:"Target possesses high 'Craftiness' rating. Warning: Target is charging a 'Kienzan' (Destructo-Disc). This attack can bypass the durability of much stronger opponents. Tactical Advice: Do not attempt to block; focus entirely on evasion. Verdict: UNDERESTIMATE AT YOUR PERIL.", img:"krillin/krillin.png"}
     ]},
    {id:"dende",   name:"DENDE",   race:"NAMEKIAN (Support Class)", color:0x00FF66, img:"dende/dende.png",
     desc:"A young Namekian with the rare gift of healing. While not a warrior, his courage on Planet Namek and his role as Earth's Guardian have saved the Z-Fighters from total annihilation more times than any dragon wish.",
     stats:[10, 10, 10, 10],
     forms: [
         {name:"BASE",       powerLevel:"10",                 desc:"The Guardian of Earth.", intel:"Vital Support Unit detected. Target is capable of total cellular regeneration through touch. Tactical Analysis: Eliminating this unit is key to preventing the main combatants from recovering. Warning: Target is currently protected by a high-level Saiyan signature. Verdict: HIGH-VALUE ASSET / PROTECT AT ALL COSTS.", img:"dende/dende.png"}
     ]},
    {id:"ginyu",   name:"GINYU FORCE", race:"MUTANT MERCENARIES", color:0x9900FF, img:"ginyuforce/ginyuforce.png",
     desc:"Frieza's elite mercenary task force. Known for their flamboyant poses and terrifying team synergy, they are the strongest military unit in the Frieza Force. Each member possesses a unique, deadly specialty.",
     stats:[450000, 450000, 450000, 450000],
     forms: [
         {name:"SQUAD",      powerLevel:"450,000",            desc:"The strongest military unit in the universe.", intel:"Extreme Pose Synergy detected. Warning: Target 'Captain Ginyu' possesses a 'Body Change' ability. If his health drops below 10%, immediate evasion is required. Analysis: Jeice and Burter are coordinating a high-speed 'Purple Comet' attack. Chance of survival: Minimal. Verdict: GINYU FORCE RULES.", img:"ginyuforce/ginyuforce.png"}
     ]},
    {id:"frieza",  name:"FRIEZA",  race:"UNKNOWN",     color:0x800080, img:"frieza/frieza.png",
     desc:"The Emperor of the Universe. A cold, calculating tyrant who ruled through fear. Frieza is a prodigy of destruction, possessing a natural power that most warriors spend lifetimes trying to achieve.",
     stats:[120000000, 120000000, 120000000, 120000000],
     forms: [
         {name:"FINAL FORM", powerLevel:"120,000,000",        desc:"Frieza's sleek, true self. In this state, he possesses enough power to extinguish entire planets with a single finger. Pure, unfiltered malice.", intel:"Target is suppressing 50% of his power. Even at half-capacity, he is the most dangerous entity in the galaxy. Analysis: Target is prone to psychological torture before delivering the lethal blow.", img:"frieza/frieza.png"},
         {name:"GOLDEN",     powerLevel:"45,000,000,000,000", desc:"The result of four months of intense malice. A transformation that allows the Emperor to stand toe-to-toe with the power of the Gods.", intel:"KI DENSITY ERROR. Target has achieved 'True Evolution.' He is no longer a mortal; he is a golden god of destruction. Recommendation: Total retreat.", img:"frieza/golden frieza.png"}
     ]}
];
var grayM:Array = [
                0.33,0.33,0.33,0,-30,
                0.33,0.33,0.33,0,-30,
                0.33,0.33,0.33,0,-30,
                0,   0,   0,   1,  0
            ];

            var modal:CharacterModal = new CharacterModal();
            modal.visible = false;

            var scrollContainer:Sprite = new Sprite();
            scnRoster.addChild(scrollContainer);

            for (var i:int = 0; i < chars.length; i++) {
                (function(ch:Object, idx:int):void {
                    var card:Sprite = new Sprite();
                    card.graphics.beginFill(0x0c0c18, 0.7); // Dark transparent backing
                    card.graphics.lineStyle(1, 0x00BFFF, 0.3); // Neon blue subtle edge
                    card.graphics.drawRoundRect(0, 0, 200, 280, 8, 8);
                    card.graphics.endFill();
                    // Wrap Roster cards cleanly into a 4-column grid so Frieza doesn't get cut off on the right!
                    var col:int = idx % 4;
                    var row:int = Math.floor(idx / 4);
                    card.x = 210 + col * 220; 
                    card.y = 145 + row * 290;
                    
                    card.buttonMode = true; card.mouseChildren = false;

                    var imgHolder:Sprite = new Sprite();
                    imgHolder.filters = [new ColorMatrixFilter(grayM)];
                    card.addChild(imgHolder);

                                        var cleanImg:String = ch.img.replace(/ /g, "%20");
                    var attemptPaths:Array = [
                        "../assets/" + cleanImg, 
                        "assets/" + cleanImg, 
                        "../../assets/" + cleanImg,
                        "C:/Users/10muk/Downloads/dragonball/assets/" + cleanImg
                    ];
                    var pathIdx:int = 0;
                    var tryNextPath:Function = null;
                    var ldr:Loader = new Loader();
                    imgHolder.addChild(ldr); // STRONG REFERENCE TO PREVENT GARBAGE COLLECTION ABORT!
                    ldr.alpha = 0; // Hide until resized
                    
                    tryNextPath = function(e:IOErrorEvent = null):void {
                        if (pathIdx < attemptPaths.length) {
                            var p:String = attemptPaths[pathIdx++];
                            try { ldr.load(new URLRequest(p)); } catch(err:Error) { tryNextPath(); }
                        }
                    };

                    ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):void {
                        var img:DisplayObject = ldr.content;
                        var targetW:Number = 186;
                        var targetH:Number = 270;
                        var scaleW:Number = targetW / img.width;
                        var scaleH:Number = targetH / img.height;
                        var scale:Number = Math.min(scaleW, scaleH);
                        
                        if (img is flash.display.Bitmap) {
                            (img as flash.display.Bitmap).smoothing = true;
                        }
                        
                        img.width *= scale;
                        img.height *= scale;
                        
                        img.x = (200 - img.width) / 2;
                        img.y = (280 - img.height) / 2 - 10;
                        ldr.alpha = 1;
                    });
                    ldr.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, tryNextPath);
                    tryNextPath();

                    // Dark gradient at the bottom so text pops
                    var grad:Shape = new Shape();
                    var mat:Matrix = new Matrix();
                    mat.createGradientBox(200, 90, Math.PI / 2, 0, 190);
                    grad.graphics.beginGradientFill("linear",[0x040410,0x040410],[0,0.98],[0,255],mat);
                    grad.graphics.drawRect(0, 190, 200, 90);
                    grad.graphics.endFill();
                    card.addChild(grad);

                    card.addChild(mkTF(ch.name, 10, 230, 180, 28, 0xffffff, 22, true, "left", "Orbitron"));
                    card.addChild(mkTF(ch.race, 10, 256, 180, 16, 0x00ff41,  8, false,"left", "Orbitron"));

                    // The bright green fill-up scan bar (matches HTML)
                    var scanTrack:Shape = new Shape();
                    scanTrack.graphics.beginFill(0x003300, 0.6);
                    scanTrack.graphics.drawRect(0, 277, 200, 3);
                    scanTrack.graphics.endFill();
                    card.addChild(scanTrack);

                    var scanBar:Shape = new Shape();
                    scanBar.graphics.beginFill(0x00ff41);
                    scanBar.graphics.drawRect(0, 277, 200, 3);
                    scanBar.graphics.endFill();
                    scanBar.scaleX = 0;
                    scanBar.filters = [new GlowFilter(0x00ff41, 1, 8, 8, 3)];
                    card.addChild(scanBar);

                    // Animate fill-up when hovering
                    var fillTimer:Timer;
                    var fillStep:int = 0;

                    card.addEventListener(MouseEvent.ROLL_OVER, function(ev:MouseEvent):void {
                        imgHolder.filters = []; // colour restore
                        card.filters = [new GlowFilter(ch.color, 0.8, 22, 22, 2)];
                        card.graphics.clear();
                        card.graphics.beginFill(0x0e0e1e, 0.95);
                        card.graphics.lineStyle(1, ch.color, 0.6);
                        card.graphics.drawRoundRect(0,0,200,280,4,4);
                        card.graphics.endFill();
                        playHover();
                        // Animate scan bar filling up
                        if (fillTimer) fillTimer.stop();
                        fillStep = 0; scanBar.scaleX = 0;
                        fillTimer = new Timer(15, 20);
                        fillTimer.addEventListener(TimerEvent.TIMER, function(te:Event):void {
                            fillStep++;
                            scanBar.scaleX = fillStep / 20;
                        });
                        fillTimer.start();
                    });
                    card.addEventListener(MouseEvent.ROLL_OUT, function(ev:MouseEvent):void {
                        imgHolder.filters = [new ColorMatrixFilter(grayM)];
                        card.filters = [];
                        card.graphics.clear();
                        card.graphics.beginFill(0x0e0e1e, 0.8);
                        card.graphics.lineStyle(1, 0x24244a);
                        card.graphics.drawRoundRect(0,0,200,280,4,4);
                        card.graphics.endFill();
                        if (fillTimer) fillTimer.stop();
                        scanBar.scaleX = 0;
                    });
                    card.addEventListener(MouseEvent.CLICK, function(ev:MouseEvent):void {
                        playClick();
                        modal.populate(ch, null); // Callback removed because modal handles its own image now
                        modal.visible = true;
                    });
                    scrollContainer.addChild(card);
                })(chars[i], i);
            }

            // Implement Mouse Wheel Scrolling
            var maxRosterScroll:Number = Math.min(0, 720 - (145 + Math.ceil(chars.length / 4) * 290) - 50);
            stage.addEventListener(MouseEvent.MOUSE_WHEEL, function(e:MouseEvent):void {
                if (contentLayer.contains(scnRoster) && modal.visible == false) {
                    scrollContainer.y += e.delta * 20;
                    if (scrollContainer.y > 0) scrollContainer.y = 0;
                    if (scrollContainer.y < maxRosterScroll) scrollContainer.y = maxRosterScroll;
                }
            });

            scnRoster.addChild(modal);
        }

// ----------------------------------------------------------------------------------
        //  GAMES
// ----------------------------------------------------------------------------------
        private function buildGames():void {
            scnGames = new Sprite();
            contentLayer.addChild(scnGames);
            gameUI = new Sprite();
            scnGames.addChild(gameUI);

            gameUI.addChild(mkTF("TRAINING ROOM",         0, 150, 1280, 60, 0x00BFFF, 52, true,  "center","Orbitron"));
            gameUI.addChild(mkTF(":: SELECT YOUR TRIAL ::",0, 215, 1280, 28, 0x00ff41, 10, false, "center","Orbitron"));

            var g1:Sprite = mkGameCard("01","FUSION RITUAL","FUSION DANCE",
                "Match arrow combos on the beat to achieve FUSION.", 100, 280);
            g1.addEventListener(MouseEvent.CLICK, function(ev:MouseEvent):void {
                playClick(); clearGame(); gameUI.visible = false; hudLayer.visible = false;
                var fd:FusionDance = new FusionDance();
                activeGame = fd; scnGames.addChild(fd); fd.startFusion();
                fd.addEventListener("EXIT_GAME", function(e:Event):void { clearGame(); });
            });
            gameUI.addChild(g1);

            var g2:Sprite = mkGameCard("02","SNAKE WAY","Z-RUNNER EVASION",
                "High speed evasion training on Snake Way.", 660, 280);
            g2.addEventListener(MouseEvent.CLICK, function(ev:MouseEvent):void {
                playClick(); clearGame(); gameUI.visible = false; hudLayer.visible = false;
                var zr:ZRunner = new ZRunner();
                activeGame = zr; scnGames.addChild(zr); zr.startRun();
                zr.addEventListener("EXIT_GAME", function(e:Event):void { clearGame(); });
            });
            gameUI.addChild(g2);
        }

        private function mkGameCard(num:String, tag:String, title:String, desc:String,
                                     x:Number, y:Number):Sprite {
            var card:Sprite = new Sprite();
            card.graphics.beginFill(0x0c0c18, 0.7); // Glass backing
            card.graphics.lineStyle(2, 0x00BFFF, 0.4); // Cyan neon border
            card.graphics.drawRoundRect(0, 0, 480, 250, 12, 12);
            card.graphics.endFill();
            card.filters = [new GlowFilter(0x00BFFF, 0.2, 15, 15, 1)];
            
            card.x = x; card.y = y; card.buttonMode = true; card.mouseChildren = false;

            // Ghost number
            var ghost:TextField = mkTF(num, 350, -15, 130, 90, 0x00BFFF, 72, true, "right", "Orbitron");
            ghost.alpha = 0.15;
            card.addChild(ghost);

            card.addChild(mkTF(tag,   24, 20, 250, 18, 0xFFD700, 10,  false, "left", "Orbitron"));
            card.addChild(mkTF(title, 24, 42, 430, 36, 0xffffff, 32, true,  "left", "Orbitron"));
            card.addChild(mkTF(desc,  24, 85, 430, 56, 0xaaaaaa, 12, false, "left", "Orbitron"));

            var lb:Sprite = new Sprite();
            lb.graphics.beginFill(0x111122, 0.9);
            lb.graphics.lineStyle(1, 0xFFD700, 0.8);
            lb.graphics.drawRoundRect(0, 0, 150, 36, 6, 6);
            lb.graphics.endFill();
            lb.x = 24; lb.y = 170;
            lb.addChild(mkTF("LAUNCH", 0, 8, 150, 20, 0xFFD700, 10, false, "center", "Orbitron"));
            card.addChild(lb);

            card.addEventListener(MouseEvent.ROLL_OVER, function(ev:MouseEvent):void {
                card.filters = [new GlowFilter(0x00BFFF, 0.7, 25, 25, 2)]; playHover();
            });
            card.addEventListener(MouseEvent.ROLL_OUT,  function(ev:MouseEvent):void { 
                card.filters = [new GlowFilter(0x00BFFF, 0.2, 15, 15, 1)]; 
            });
            return card;
        }

        private function clearGame():void {
            var ag:Sprite = activeGame as Sprite;
            activeGame = null;
            if (ag && ag.parent) ag.parent.removeChild(ag);
            if (gameUI) gameUI.visible = true;
            if (hudLayer) hudLayer.visible = true;
        }

// ----------------------------------------------------------------------------------
        //  UI HELPERS
// ----------------------------------------------------------------------------------
        private function mkTF(text:String,x:Number,y:Number,w:Number,h:Number,color:uint,
                               size:Number,bold:Boolean,align:String,font:String):TextField {
            var tf:TextField = new TextField();
            var fmt:TextFormat = new TextFormat(font, size, color, bold);
            fmt.align = align;
            tf.defaultTextFormat = fmt;
            tf.width=w; tf.height=h; tf.x=x; tf.y=y;
            tf.text=text; tf.selectable=false; tf.mouseEnabled=false;
            
            tf.antiAliasType = flash.text.AntiAliasType.ADVANCED;
            tf.gridFitType = flash.text.GridFitType.PIXEL;
            tf.sharpness = 100;
            tf.thickness = -50;
            tf.embedFonts = false;
            
            return tf;
        }

        private function mkBtn(label:String,x:Number,y:Number,w:Number,h:Number,
                                bg:uint,fg:uint,outline:Boolean,glowCol:uint):Sprite {
            var s:Sprite = new Sprite();
            s.graphics.beginFill(bg);
            s.graphics.drawRoundRect(0,0,w,h,8,8);
            s.graphics.endFill();
            if (outline) {
                s.graphics.lineStyle(1, fg, 0.4);
                s.graphics.drawRoundRect(0,0,w,h,8,8);
            }
            s.addChild(mkTF(label, 0, (h-18)/2, w, 18, fg, 10, true, "center", "Orbitron"));
            s.x=x; s.y=y; s.buttonMode=true; s.mouseChildren=false;
            s.addEventListener(MouseEvent.ROLL_OVER, function(ev:MouseEvent):void {
                s.filters=[new GlowFilter(glowCol,0.7,18,18,2)]; s.alpha=0.9; playHover();
            });
            s.addEventListener(MouseEvent.ROLL_OUT, function(ev:MouseEvent):void {
                s.filters=[]; s.alpha=1;
            });
            return s;
        }

        private function mkNavBtn(label:String,x:Number,y:Number,w:Number,h:Number,col:uint):Sprite {
            var s:Sprite = new Sprite();
            s.graphics.beginFill(0x0c0c18, 0.01);
            s.graphics.lineStyle(1, col, 0.25);
            s.graphics.drawRect(0,0,w,h);
            s.graphics.endFill();
            var t:TextField = mkTF(label, 0, 6, w, h, 0xaaaaaa, 10, true, "center", "Orbitron");
            s.addChild(t);
            s.x=x; s.y=y; s.buttonMode=true; s.mouseChildren=false;
            s.addEventListener(MouseEvent.ROLL_OVER, function(ev:MouseEvent):void {
                t.textColor = col;
                s.filters=[new GlowFilter(col,0.7,16,16,2)];
                s.graphics.clear();
                s.graphics.beginFill(0x0c0c18,0.01);
                s.graphics.lineStyle(1,col,0.9);
                s.graphics.drawRect(0,0,w,h);
                s.graphics.endFill();
                playHover();
            });
            s.addEventListener(MouseEvent.ROLL_OUT, function(ev:MouseEvent):void {
                t.textColor=0xaaaaaa; s.filters=[];
                s.graphics.clear();
                s.graphics.beginFill(0x0c0c18,0.01);
                s.graphics.lineStyle(1,col,0.25);
                s.graphics.drawRect(0,0,w,h);
                s.graphics.endFill();
            });
            return s;
        }

        private function onKey(e:KeyboardEvent):void {
            // Keyboard smooth scroll for Manga Viewer
            if (scnManga != null && contentLayer.contains(scnManga) && mangaScrollContainer != null) {
                if (e.keyCode == 32 || e.keyCode == 40) mangaScrollTarget -= 350; // SPACE or DOWN
                if (e.keyCode == 38) mangaScrollTarget += 350; // UP
                
                var maxScroll:Number = Math.max(0, mangaTotalHeight - 660);
                if (mangaScrollTarget > 0) mangaScrollTarget = 0;
                if (mangaScrollTarget < -maxScroll) mangaScrollTarget = -maxScroll;
            }
        }

        private function loadSmart(ldr:Loader, path:String):void {
            if (!path) return;
            var cleanPath:String = path;
            var tryParent:Function = function(e:IOErrorEvent):void {
                ldr.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, tryParent);
                // Add a final silent listener to catch asynchronous #2035 URL Not Found errors on the second try
                ldr.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, function(e2:IOErrorEvent):void {});
                try { ldr.load(new URLRequest("../assets/" + cleanPath)); } catch(err:Error){}
            };
            ldr.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, tryParent);
            try { ldr.load(new URLRequest("assets/" + cleanPath)); } catch(err:Error){}
        }
    }
}





















