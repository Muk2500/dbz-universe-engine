/**
 * Recursive Data Modal & UI Overlay System
 * 
 * Handles dynamic data rendering and interactive state swaps for the Galactic Archive.
 * Utilizes custom ColorMatrixFilter algorithms for visual transitions and 
 * programmatic rendering of tactical combat data via the Scouter HUD metaphor.
 */
package ui {
    import flash.display.*;
    import flash.events.*;
    import flash.filters.DropShadowFilter;
    import flash.filters.GlowFilter;
    import flash.text.*;
    import flash.utils.Timer;
    import flash.media.Sound;
    import flash.geom.Point;
    import flash.display.Loader;
    import flash.net.URLRequest;
    
    public class CharacterModal extends Sprite {
        
        private var bg:Sprite;
        private var nameTF:TextField;
        private var raceTF:TextField;
        private var closeBtn:Sprite;
        private var statsLayer:Sprite;
        private var transLayer:Sprite;
        private var flickerTimer:Timer;
        private var shakeTimer:Timer;
        private var imgContainer:Sprite;

        public function CharacterModal() {
            // Semi transparent black overlay
            this.graphics.beginFill(0x000000, 0.88);
            this.graphics.drawRect(-400, -200, 2000, 1080);
            this.graphics.endFill();
            
            bg = new Sprite();
            bgShape = new Sprite();
            bgShape.graphics.beginFill(0x0e0e1e);
            bgShape.graphics.lineStyle(2, 0xFFD700, 0.2);
            bgShape.graphics.drawRoundRect(0, 0, 750, 500, 6, 6);
            bgShape.graphics.endFill();
            bgShape.filters = [new DropShadowFilter(0, 0, 0x000000, 1.0, 30, 30, 2, 1)];
            bg.addChild(bgShape);
            
            bg.x = (1280 - 750) / 2;
            bg.y = (720 - 500) / 2;
            addChild(bg);
            
            // Close Button
            closeBtn = new Sprite();
            closeBtn.graphics.lineStyle(1, 0xffffff, 0.2);
            closeBtn.graphics.beginFill(0x000000, 0);
            closeBtn.graphics.drawRect(0, 0, 80, 25);
            closeBtn.graphics.endFill();
            closeBtn.x = 650; closeBtn.y = 15;
            closeBtn.buttonMode = true;
            bg.addChild(closeBtn);
            
            var ctTF:TextField = mkEmbedTF("\u2715 CLOSE", 10, 4, 70, 18, 0xaaaaaa, 9, false, "left", "Orbitron");
            closeBtn.addChild(ctTF);
            
            closeBtn.addEventListener(MouseEvent.MOUSE_OVER, function(e:MouseEvent):void {
                ctTF.textColor = 0xFF0000;
                closeBtn.graphics.clear();
                closeBtn.graphics.lineStyle(1, 0xFF0000, 0.8);
                closeBtn.graphics.beginFill(0x000000, 0);
                closeBtn.graphics.drawRect(0, 0, 80, 25);
                closeBtn.graphics.endFill();
            });
            closeBtn.addEventListener(MouseEvent.MOUSE_OUT, function(e:MouseEvent):void {
                ctTF.textColor = 0xaaaaaa;
                closeBtn.graphics.clear();
                closeBtn.graphics.lineStyle(1, 0xffffff, 0.2);
                closeBtn.graphics.beginFill(0x000000, 0);
                closeBtn.graphics.drawRect(0, 0, 80, 25);
                closeBtn.graphics.endFill();
            });
            closeBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
                visible = false;
            });
            
            // Race tag
            raceTF = mkEmbedTF("", 40, 40, 300, 20, 0x00ff41, 9, false, "left", "Orbitron");
            bg.addChild(raceTF);
            
            // Name
            nameTF = mkEmbedTF("", 35, 58, 400, 56, 0xFFFFFF, 48, true, "left", "Bebas Neue");
            bg.addChild(nameTF);
            
            // Stats
            statsLayer = new Sprite();
            statsLayer.x = 40; statsLayer.y = 190;
            bg.addChild(statsLayer);

            // Transformation tree
            transLayer = new Sprite();
            transLayer.x = 40; transLayer.y = 340;
            bg.addChild(transLayer);
            
            // Image Container (Right Side)
            imgContainer = new Sprite();
            imgContainer.x = 400; imgContainer.y = 80;
            bg.addChild(imgContainer);
            
            // Confirm Button (Level 5 Feature)
            var confirmBtn:Sprite = new Sprite();
            confirmBtn.name = "confirmBtn";
            confirmBtn.graphics.beginFill(0xFFD700);
            confirmBtn.graphics.drawRoundRect(0,0, 150, 30, 8, 8);
            confirmBtn.graphics.endFill();
            var confTF:TextField = mkEmbedTF("SCAN FORM", 0, 6, 150, 18, 0x000000, 14, true, "center", "Bebas Neue");
            confirmBtn.addChild(confTF);
            confirmBtn.x = 40; confirmBtn.y = 460;
            confirmBtn.buttonMode = true; confirmBtn.mouseChildren = false;
            bg.addChild(confirmBtn);
            
            var self:CharacterModal = this;
            confirmBtn.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
                if (!currentForm) return;
                
                // Play sounds for SCAN FORM - using exact wav Class names
                playSnd(["fullpower1_wav", "fullpower1", "FullPower1"]);
                playSnd(["explosivewave1_wav", "explosivewave1", "ScouterBeep"]);
                
                // CREATE THE EPIC SCOUTER RADAR OVERLAY
                var scouterOverlay:Sprite = new Sprite();
                // Draw a massive background that covers the entire screen, even outside the modal bounds
                scouterOverlay.graphics.beginFill(0x001100, 0.95);
                scouterOverlay.graphics.drawRect(-500, -300, 3000, 2000);
                scouterOverlay.graphics.endFill();
                
                // Add solid dark background to hide the underlying modal text from bleeding through!
                scouterOverlay.graphics.beginFill(0x050505, 0.95);
                scouterOverlay.graphics.drawRect(-1000, -1000, 3200, 2000);
                scouterOverlay.graphics.endFill();
                
                // Draw Radar Grid
                scouterOverlay.graphics.lineStyle(1, 0x00FF41, 0.15);
                for(var gx:int = -500; gx < 2500; gx += 50) { scouterOverlay.graphics.moveTo(gx, -300); scouterOverlay.graphics.lineTo(gx, 1500); }
                for(var gy:int = -300; gy < 1500; gy += 50) { scouterOverlay.graphics.moveTo(-500, gy); scouterOverlay.graphics.lineTo(2500, gy); }
                
                // Draw Radar Circle centered on the screen (1280x720)
                var cx:Number = 640; var cy:Number = 360; 
                scouterOverlay.graphics.lineStyle(3, 0x00FF41, 0.8);
                scouterOverlay.graphics.drawCircle(cx, cy, 300);
                scouterOverlay.graphics.drawCircle(cx, cy, 200);
                scouterOverlay.graphics.drawCircle(cx, cy, 100);
                scouterOverlay.graphics.moveTo(cx - 320, cy); scouterOverlay.graphics.lineTo(cx + 320, cy);
                scouterOverlay.graphics.moveTo(cx, cy - 320); scouterOverlay.graphics.lineTo(cx, cy + 320);
                
                // Radar Sweep Line
                var sweep:Sprite = new Sprite();
                sweep.x = cx; sweep.y = cy;
                sweep.graphics.beginFill(0x00FF41, 0.4);
                sweep.graphics.moveTo(0, 0);
                sweep.graphics.lineTo(300, 0);
                sweep.graphics.lineTo(280, 100);
                sweep.graphics.lineTo(0, 0);
                sweep.graphics.endFill();
                scouterOverlay.addChild(sweep);
                
                // Analyzing Text
                var analyzingTF:TextField = mkEmbedTF("ANALYZING TARGET DATA...", cx - 200, cy - 25, 400, 50, 0x00ff41, 32, true, "center", "Bebas Neue");
                analyzingTF.filters = [new GlowFilter(0x00ff41, 1, 10, 10, 1)];
                scouterOverlay.addChild(analyzingTF);
                
                // Add overlay to the parent container so it respects game coordinates and stays under the custom cursor
                if (self.parent) {
                    self.parent.addChild(scouterOverlay);
                    scouterOverlay.x = 0; scouterOverlay.y = 0;
                } else {
                    self.addChild(scouterOverlay);
                    var globalPt:Point = self.localToGlobal(new Point(0, 0));
                    scouterOverlay.x = -globalPt.x; scouterOverlay.y = -globalPt.y;
                }
                
                // Animate the sweep using a reliable Timer instead of ENTER_FRAME
                var angle:Number = 0;
                var animTimer:Timer = new Timer(33);
                animTimer.addEventListener(TimerEvent.TIMER, function(ev:Event):void {
                    angle += 12;
                    sweep.rotation = angle;
                    analyzingTF.visible = (Math.random() > 0.1); // Flicker text
                });
                animTimer.start();
                
                // After 2.5 seconds, stop the radar and show the Tactical Analysis directly on the overlay!
                var finishScanTimer:Timer = new Timer(2500, 1);
                finishScanTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function(te:Event):void {
                    animTimer.stop();
                    analyzingTF.visible = false;
                    sweep.visible = false;
                    
                    var intelStr:String = currentForm.intel ? currentForm.intel : (currentForm.desc ? currentForm.desc : "NO COMBAT INTEL AVAILABLE.");
                    
                    // Trigger a massive flashing red alert if the intel contains Warning or Anomaly!
                    var warnMatch:Boolean = (intelStr.toUpperCase().indexOf("WARNING") != -1 || intelStr.toUpperCase().indexOf("ANOMALY") != -1);
                    if (warnMatch) {
                        var wText:String = intelStr.toUpperCase().indexOf("ANOMALY") != -1 ? "ANOMALY DETECTED" : "WARNING: HIGH THREAT";
                        var warnTF:TextField = mkEmbedTF(wText, cx - 200, cy - 270, 400, 50, 0xFF0000, 48, true, "center", "Bebas Neue");
                        warnTF.filters = [new GlowFilter(0xFF0000, 1, 10, 10, 1)];
                        scouterOverlay.addChild(warnTF);
                        
                        var wTimer:Timer = new Timer(300);
                        wTimer.addEventListener(TimerEvent.TIMER, function(we:Event):void { warnTF.visible = !warnTF.visible; });
                        wTimer.start();
                    }
                    
                    // Show Tactical Analysis on the Radar Screen
                    var intelOverlay:TextField = mkEmbedTF("TACTICAL ANALYSIS:\n" + intelStr, cx - 350, cy - 180, 700, 200, 0x00ff41, 22, false, "center", "Orbitron");
                    intelOverlay.wordWrap = true; intelOverlay.multiline = true;
                    intelOverlay.filters = [new GlowFilter(0x00ff41, 0.9, 4, 4, 1)];
                    scouterOverlay.addChild(intelOverlay);
                    
                    // Show Power Level on the Radar Screen
                    var plOverlay:TextField = mkEmbedTF("", cx - 200, cy + 60, 400, 100, 0x00ff41, 44, true, "center", "Bebas Neue");
                    plOverlay.filters = [new GlowFilter(0x00ff41, 0.9, 6, 6, 1)];
                    scouterOverlay.addChild(plOverlay);
                    
                    var rawStr:String = (currentForm.powerLevel ? currentForm.powerLevel : "10000").replace(/,/g, "");
                    var isNumeric:Boolean = !isNaN(parseFloat(rawStr));
                    var finalPL:String = currentForm.powerLevel ? currentForm.powerLevel : "10000";
                    
                    var flickTimer:Timer = new Timer(30, 40); // 1.2 second flicker
                    
                    var loopSnd:Sound;
                    try { var countCls:Class = flash.utils.getDefinitionByName("ARC_MENU_SYS_NumCount_ogg") as Class; if(countCls){ loopSnd = new countCls(); } } catch(err:Error) {}
                    if (!loopSnd) { try { var countCls2:Class = flash.utils.getDefinitionByName("ARC_MENU_SYS_NumCount") as Class; if(countCls2){ loopSnd = new countCls2(); } } catch(err:Error) {} }
                    if (!loopSnd) { try { var countCls3:Class = flash.utils.getDefinitionByName("ARC_MENU_SYS_NumCount_mp3") as Class; if(countCls3){ loopSnd = new countCls3(); } } catch(err:Error) {} }
                    if (!loopSnd) { try { var countCls4:Class = flash.utils.getDefinitionByName("ARC_MENU_SYS_NumCount_wav") as Class; if(countCls4){ loopSnd = new countCls4(); } } catch(err:Error) {} }
                    var sc:flash.media.SoundChannel;
                    if (loopSnd) sc = loopSnd.play(0, 5); // Loop 5 times
                    
                    flickTimer.addEventListener(TimerEvent.TIMER, function(fte:Event):void {
                        var rStr:String = "";
                        var len:int = isNumeric ? finalPL.length : 12;
                        for(var k:int = 0; k < len; k++) {
                            if (Math.random() > 0.3) rStr += String.fromCharCode(48 + Math.floor(Math.random() * 10));
                            else rStr += finalPL.charAt(Math.floor(Math.random() * finalPL.length));
                        }
                        plOverlay.text = "POWER LEVEL\n" + rStr;
                    });
                    
                    flickTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function(fte:Event):void {
                        plOverlay.text = "POWER LEVEL\n" + finalPL;
                        
                        // Add Close Button
                        var closeScouterBtn:Sprite = new Sprite();
                        closeScouterBtn.graphics.beginFill(0x002200, 0.9);
                        closeScouterBtn.graphics.lineStyle(1, 0x00ff41, 1);
                        closeScouterBtn.graphics.drawRect(0, 0, 160, 36);
                        closeScouterBtn.graphics.endFill();
                        closeScouterBtn.x = cx - 80; closeScouterBtn.y = cy + 220;
                        closeScouterBtn.buttonMode = true; closeScouterBtn.mouseChildren = false;
                        
                        var cbTF:TextField = mkEmbedTF("CLOSE SCANNER", 0, 8, 160, 20, 0x00ff41, 14, false, "center", "Orbitron");
                        closeScouterBtn.addChild(cbTF);
                        scouterOverlay.addChild(closeScouterBtn);
                        
                        closeScouterBtn.addEventListener(MouseEvent.CLICK, function(me:MouseEvent):void {
                            playSnd(["ARC_MENU_SYS_TLP_ogg", "ARC_MENU_SYS_TLP", "ARC_MENU_SYS_TLP_mp3", "ARC_MENU_SYS_TLP_wav"]);
                            if (scouterOverlay.parent) scouterOverlay.parent.removeChild(scouterOverlay);
                            if (sc) sc.stop();
                        });
                    });
                    flickTimer.start();
                });
                finishScanTimer.start();
            });
        }
        
        private var changeImgCb:Function;
        private var currentForm:Object;
        private var currentData:Object;
        private var bgShape:Sprite;
        
        private function loadModalImage(url:String):void {
            if (!url) return;
            while (imgContainer.numChildren > 0) imgContainer.removeChildAt(0);
            
            // 1. Try to load from Animate Library first
            var bare:String = url.split(".")[0];
            try {
                var Cls:Class = flash.utils.getDefinitionByName(bare) as Class;
                if (Cls) {
                    var bmpData:flash.display.BitmapData = new Cls(0,0) as flash.display.BitmapData;
                    var bmp:flash.display.Bitmap = new flash.display.Bitmap(bmpData);
                    
                    var targetW1:Number = 320;
                    var ratio1:Number = bmp.height / bmp.width;
                    bmp.width = targetW1;
                    bmp.height = targetW1 * ratio1;
                    imgContainer.addChild(bmp);
                    
                    bmp.filters = [new GlowFilter(0x00ff41, 0.3, 15, 15, 2)];
                    
                    var fShape1:Shape = new Shape();
                    fShape1.graphics.beginFill(0xFFFFFF);
                    fShape1.graphics.drawRect(0, 0, bmp.width, bmp.height);
                    fShape1.graphics.endFill();
                    imgContainer.addChild(fShape1);
                    
                    var ft1:Timer = new Timer(30, 15);
                    ft1.addEventListener(TimerEvent.TIMER, function(te:Event):void { fShape1.alpha -= (1/15); });
                    ft1.addEventListener(TimerEvent.TIMER_COMPLETE, function(te:Event):void { if(imgContainer.contains(fShape1)) imgContainer.removeChild(fShape1); });
                    ft1.start();
                    return; // Success!
                }
            } catch(e:Error) {}

            // 2. Fallback to external file if not in Library
            var ldr:Loader = new Loader();
            imgContainer.addChild(ldr); // Add to display list immediately to prevent Garbage Collection!
            
            ldr.contentLoaderInfo.addEventListener(Event.COMPLETE, function(e:Event):void {
                var img:DisplayObject = ldr.content;
                // Swap the loader for the actual image content
                if (imgContainer.contains(ldr)) imgContainer.removeChild(ldr);
                
                var maxW:Number = 320;
                var maxH:Number = 480;
                var scaleW:Number = maxW / img.width;
                var scaleH:Number = maxH / img.height;
                var scale:Number = Math.min(scaleW, scaleH);
                
                // Hardware smoothing fixes lag but retains infinite resolution when scaling!
                if (img is flash.display.Bitmap) {
                    (img as flash.display.Bitmap).smoothing = true;
                }
                
                var customScale:Number = (currentForm && currentForm.scaleOverride) ? currentForm.scaleOverride : 1.0;
                var offsetX:Number = (currentForm && currentForm.xOffset) ? currentForm.xOffset : 0;
                var offsetY:Number = (currentForm && currentForm.yOffset) ? currentForm.yOffset : 0;
                
                img.width *= (scale * customScale);
                img.height *= (scale * customScale);
                
                // Center the image within the bounding box, plus manual offsets
                img.x = (maxW - img.width) / 2 + offsetX;
                img.y = (maxH - img.height) / 2 + offsetY;
                
                img.filters = [new GlowFilter(0x00ff41, 0.3, 15, 15, 2)];
                
                // Wrap the image in a container (no dragging)
                var dragLayer:Sprite = new Sprite();
                dragLayer.addChild(img);
                imgContainer.addChild(dragLayer);
                
                var fShape:Shape = new Shape();
                fShape.graphics.beginFill(0xFFFFFF);
                fShape.graphics.drawRect(img.x, img.y, img.width, img.height);
                fShape.graphics.endFill();
                imgContainer.addChild(fShape);
                
                var ft:Timer = new Timer(30, 15);
                ft.addEventListener(TimerEvent.TIMER, function(te:Event):void { fShape.alpha -= (1/15); });
                ft.addEventListener(TimerEvent.TIMER_COMPLETE, function(te:Event):void { if(imgContainer.contains(fShape)) imgContainer.removeChild(fShape); });
                ft.start();
            });
            
            var cleanPath:String = url.replace(/ /g, "%20");
            var attemptPaths:Array = ["../assets/" + cleanPath, "assets/" + cleanPath, "../../assets/" + cleanPath];
            var pathIdx:int = 0;
            var tryNextPath:Function = null;
            
            tryNextPath = function(e:IOErrorEvent = null):void {
                if (pathIdx < attemptPaths.length) {
                    var p:String = attemptPaths[pathIdx++];
                    try { ldr.load(new URLRequest(p)); } catch(err:Error) { tryNextPath(); }
                }
            };
            ldr.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, tryNextPath);
            tryNextPath();
        }
        
        public function populate(data:Object, cb:Function = null):void {
            this.changeImgCb = cb;
            this.currentData = data;
            
            nameTF.text = data.name;
            raceTF.text = "\u25C8 " + data.race;
            
            if (!bg.getChildByName("descTF")) {
                var dTF:TextField = mkEmbedTF("", 35, 115, 350, 80, 0xcccccc, 12, false, "left", "Orbitron");
                dTF.name = "descTF"; dTF.multiline = true; dTF.wordWrap = true;
                bg.addChild(dTF);
            }
            var descField:TextField = TextField(bg.getChildByName("descTF"));
            
            var forms:Array = data.forms ? data.forms : [];
            currentForm = (forms.length > 0) ? forms[0] : null;
            descField.text = (currentForm && currentForm.desc) ? currentForm.desc : (data.desc ? data.desc : "");
            var initLevel:String = (currentForm && currentForm.powerLevel) ? currentForm.powerLevel : "10000";
            updateStats(initLevel);
            
            loadModalImage(currentForm ? currentForm.img : data.img);

            // Dynamically resize background height based on tree length
            var maxPerRow:int = 3;
            var verticalGap:Number = 40;
            var requiredHeight:Number = 410; // Reduced base height by 70px to match transLayer moving up
            if (forms.length > 0) {
                var rows:int = Math.floor((forms.length - 1) / maxPerRow);
                requiredHeight += 90 + (rows * verticalGap); // Push down correctly for tree
            }

            // Build transformation tree
            while (transLayer.numChildren > 0) transLayer.removeChildAt(0);
            if (forms.length > 0) {
                transLayer.addChild(mkEmbedTF("TRANSFORMATION TREE", 0, 20, 300, 24, 0xFFD700, 18, true, "left", "Bebas Neue"));
                var cx:Number = 0; var cy:Number = 45;
                var horizontalGap:Number = 120;
                for (var fi:int = 0; fi < forms.length; fi++) {
                    if (fi > 0 && fi % maxPerRow == 0) {
                        cx = 0; cy += verticalGap;
                    }
                    var fData:Object = forms[fi];
                    var tag:Sprite = new Sprite();
                    tag.graphics.lineStyle(1, (fi == 0 ? 0xFFD700 : 0x333355));
                    tag.graphics.beginFill(0x0e0e1e);
                    tag.graphics.drawRect(0, 0, 80, 24);
                    tag.graphics.endFill();
                    tag.x = cx; tag.y = cy;
                    tag.buttonMode = true; tag.mouseChildren = false;
                    
                    var tagTF:TextField = mkEmbedTF(fData.name, 4, 4, 72, 16, (fi == 0 ? 0xFFD700 : 0xaaaaaa), 8, false, "center", "Orbitron");
                    tag.addChild(tagTF);
                    transLayer.addChild(tag);
                    
                    (function(f:Object, t:Sprite, txt:TextField, fName:String):void {
                        t.addEventListener(MouseEvent.CLICK, function(e:MouseEvent):void {
                            playSnd(["ARC_MENU_SYS_Decide_2_ogg", "ARC_MENU_SYS_Decide_2", "ARC_MENU_SYS_Decide_2_mp3", "ARC_MENU_SYS_Decide_2_wav"]);
                            
                            // Special Frieza Flash
                            if (fName == "GOLDEN" || fName == "BLACK") {
                                var flsh:Sprite = new Sprite();
                                flsh.graphics.beginFill(fName == "GOLDEN" ? 0x800080 : 0x000000); // Purple or Black
                                flsh.graphics.drawRect(-500, -500, 3000, 3000);
                                flsh.graphics.endFill();
                                if (stage) {
                                    stage.addChild(flsh);
                                    var fTimer:Timer = new Timer(30, 15);
                                    fTimer.addEventListener(TimerEvent.TIMER, function(te:TimerEvent):void { flsh.alpha -= 0.08; });
                                    fTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function(te:TimerEvent):void { if (flsh.parent) flsh.parent.removeChild(flsh); });
                                    fTimer.start();
                                }
                            }
                            
                            currentForm = f;
                            nameTF.text = currentData.name + " (" + fName + ")";
                            descField.text = f.desc ? f.desc : (currentData.desc ? currentData.desc : "");
                            descField.textColor = 0xcccccc;
                            descField.filters = [];
                            nameTF.filters = [];
                            raceTF.filters = [];
                            
                            var nTF:TextField = statsLayer.getChildByName("numTF") as TextField;
                            if (nTF) nTF.filters = [new GlowFilter(0x00ff41, 0.6, 8, 8, 1)];
                            
                            updateStats(f.powerLevel ? f.powerLevel : "10000");
                            if (changeImgCb != null) changeImgCb(f.img);
                            loadModalImage(f.img);
                            
                            for (var j:int = 1; j < transLayer.numChildren; j++) {
                                var child:DisplayObject = transLayer.getChildAt(j);
                                if (child is Sprite) {
                                    Sprite(child).graphics.clear();
                                    Sprite(child).graphics.lineStyle(1, 0x333355);
                                    Sprite(child).graphics.beginFill(0x0e0e1e);
                                    Sprite(child).graphics.drawRect(0, 0, 80, 24);
                                    Sprite(child).graphics.endFill();
                                    var innerTF:TextField = Sprite(child).getChildAt(0) as TextField;
                                    if (innerTF) innerTF.textColor = 0xaaaaaa;
                                }
                            }
                            t.graphics.clear(); t.graphics.lineStyle(1, 0xFFD700);
                            t.graphics.beginFill(0x0e0e1e); t.graphics.drawRect(0, 0, 80, 24); t.graphics.endFill();
                            txt.textColor = 0xFFD700;
                        });
                    })(fData, tag, tagTF, fData.name);
                    cx += horizontalGap;
                }
            }
            
            // Position SCAN FORM button near the bottom
            var scanBtn:Sprite = bg.getChildByName("confirmBtn") as Sprite;
            if (scanBtn) scanBtn.y = requiredHeight - 50;
            
            if (!bgShape) {
                bgShape = new Sprite();
                bgShape.filters = [new flash.filters.DropShadowFilter(4, 45, 0, 0.5, 8, 8)];
                bg.addChildAt(bgShape, 0);
            }
            bgShape.graphics.clear();
            bgShape.graphics.beginFill(0x0e0e1e);
            bgShape.graphics.lineStyle(2, 0xFFD700, 0.2);
            bgShape.graphics.drawRoundRect(0, 0, 750, requiredHeight, 6, 6);
            bgShape.graphics.endFill();
        }

        private function updateStats(powerLevel:String):void {
            if (flickerTimer) { flickerTimer.stop(); flickerTimer = null; }
            if (shakeTimer) { shakeTimer.stop(); shakeTimer = null; statsLayer.x = 40; statsLayer.y = 190; }

            while (statsLayer.numChildren > 0) statsLayer.removeChildAt(0);
            statsLayer.addChild(mkEmbedTF("\u25C8 COMBAT ANALYSIS", 0, 0, 200, 18, 0x8888aa, 9, true, "left", "Orbitron"));
            
            var rawStr:String = powerLevel.replace(/,/g, "");
            var numericVal:Number = parseFloat(rawStr);
            var isNumeric:Boolean = !isNaN(numericVal);
            var pct:Number = isNumeric ? Math.min(1.0, numericVal / 50000000000) : 1.0;
            
            var bars:Array = ["STRENGTH", "SPEED", "KI CONTROL", "ENDURANCE"];
            for (var i:int = 0; i < bars.length; i++) {
                var lTF:TextField = mkEmbedTF(bars[i], 0, 25 + (i * 18), 100, 16, 0xFFFFFF, 9, false, "left", "Orbitron");
                statsLayer.addChild(lTF);
                
                var maxW:Number = 300;
                var barPct:Number = isNumeric ? Math.max(0.1, pct + (Math.random() * 0.2 - 0.1)) : (0.9 + Math.random() * 0.1);
                if (barPct > 1.0) barPct = 1.0;
                
                var track:Shape = new Shape();
                track.graphics.beginFill(0x222233);
                track.graphics.drawRect(100, 25 + (i * 18) + 4, maxW, 6);
                track.graphics.endFill();
                statsLayer.addChild(track);
                
                var fill:Shape = new Shape();
                fill.graphics.beginFill(0x00BFFF);
                fill.graphics.drawRect(100, 25 + (i * 18) + 4, maxW * barPct, 6);
                fill.graphics.endFill();
                fill.filters = [new GlowFilter(0x00BFFF, 0.8, 6, 6, 2, 1)];
                statsLayer.addChild(fill);
            }
            
            statsLayer.addChild(mkEmbedTF("POWER LEVEL", 0, 105, 200, 18, 0xFFD700, 16, true, "left", "Bebas Neue"));
            var numTF:TextField = mkEmbedTF("0", 0, 120, 400, 40, 0x00ff41, 32, true, "left", "Bebas Neue");
            numTF.name = "numTF"; // Named so we can access it during Scouter Sequence
            numTF.filters = [new GlowFilter(0x00ff41, 0.6, 8, 8, 1)];
            statsLayer.addChild(numTF);
            
            flickerTimer = new Timer(30, 20);
            flickerTimer.addEventListener(TimerEvent.TIMER, function(te:Event):void {
                var rStr:String = "";
                var len:int = isNumeric ? powerLevel.length : 12;
                for(var j:int = 0; j < len; j++) {
                    if (Math.random() > 0.3) rStr += String.fromCharCode(48 + Math.floor(Math.random() * 10));
                    else rStr += powerLevel.charAt(Math.floor(Math.random() * powerLevel.length));
                }
                numTF.text = rStr;
            });
            flickerTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function(te:Event):void {
                numTF.text = powerLevel;
                shakeTimer = new Timer(20, 10);
                var origX:Number = 40;
                var origY:Number = 190;
                shakeTimer.addEventListener(TimerEvent.TIMER, function(se:Event):void {
                    statsLayer.x = origX + (Math.random() * 8 - 4);
                    statsLayer.y = origY + (Math.random() * 8 - 4);
                });
                shakeTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function(se:Event):void {
                    statsLayer.x = origX;
                    statsLayer.y = origY;
                });
                shakeTimer.start();
            });
            flickerTimer.start();
        }

        private function mkEmbedTF(text:String, x:Number, y:Number, w:Number, h:Number, color:uint, size:Number, bold:Boolean, align:String, font:String):TextField {
            var tf:TextField = new TextField();
            var realFontName:String = font;
            var canEmbed:Boolean = false;
            
            try {
                if (font == "Bebas Neue") {
                    var BClass:Class = flash.utils.getDefinitionByName("BebasFont") as Class;
                    if (BClass) {
                        flash.text.Font.registerFont(BClass);
                        var bFont:flash.text.Font = new BClass() as flash.text.Font;
                        realFontName = bFont.fontName;
                        canEmbed = true;
                    }
                } else if (font == "Orbitron") {
                    var OClass:Class = flash.utils.getDefinitionByName("OrbitronFont") as Class;
                    if (OClass) {
                        flash.text.Font.registerFont(OClass);
                        var oFont:flash.text.Font = new OClass() as flash.text.Font;
                        realFontName = oFont.fontName;
                        canEmbed = true;
                    }
                }
            } catch(e:Error) {}

            var fmt:TextFormat = new TextFormat(realFontName, size, color, bold);
            fmt.align = align;
            tf.defaultTextFormat = fmt;
            tf.width = w; tf.height = h; tf.x = x; tf.y = y;
            tf.text = text; tf.selectable = false; tf.mouseEnabled = false;
            if (canEmbed) tf.embedFonts = true;
            tf.antiAliasType = flash.text.AntiAliasType.ADVANCED;
            return tf;
        }
        
        private function playSnd(names:Array):void {
            for each (var nm:String in names) {
                try {
                    var Cls:Class = flash.utils.getDefinitionByName(nm) as Class;
                    if(Cls){
                        var snd:Sound = new Cls();
                        snd.play();
                        return;
                    }
                } catch(err:Error) {}
            }
        }
    }
}

