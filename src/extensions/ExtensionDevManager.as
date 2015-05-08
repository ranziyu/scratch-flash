/*
 * Scratch Project Editor and Player
 * Copyright (C) 2014 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

package extensions {
import flash.events.*;
import flash.net.*;
import flash.utils.clearInterval;
import flash.utils.setInterval;

import uiwidgets.DialogBox;

public class ExtensionDevManager extends ExtensionManager {

	public var localExt:ScratchExtension = null;
	public var localFilePoller:uint = 0;
	private var localFileRef:FileReference;
	private var localExtSaved:Boolean = true;
	public function ExtensionDevManager(app:Scratch) {
		super(app);
	}

	public function getLocalFileName(ext:ScratchExtension = null):String {
		if(localFileRef && (ext === localExt || ext == null)) return localFileRef.name;

		return null;
	}

	public function isLocalExtensionSaved():Boolean {
		return !localExt || (localExtSaved && !localFileDirty);
	}

	public function isLocalExtensionDirty(ext:ScratchExtension = null):Boolean {
		return (!ext || ext == localExt) && localExt && localFileDirty;
	}

	// Override so that we can keep the reference to the local extension
	private var rawExtensionLoaded:Boolean = false;
	override public function loadRawExtension(extObj:Object):ScratchExtension {
		var ext:ScratchExtension = extensionDict[extObj.extensionName];
		var isLocalExt:Boolean = (localExt && ext == localExt) || (localFilePoller && !localExt);
		ext = super.loadRawExtension(extObj);
		if(isLocalExt) {
			if(!localExt) {
				DialogBox.notify('Extensions', 'Your local extension "' + ext.name +
						'" is now loaded.The editor will notice when ' + localFileRef.name +
						' is\nsaved and offer you to reload the extension. Reloading an extension will stop the project.');
			}
			localExt = ext;
			localExtSaved = false;
			app.updatePalette();
			app.setSaveNeeded();
		}

		rawExtensionLoaded = true;
		return ext;
	}

	// -----------------------------
	// Javascript Extension Development
	//------------------------------

	private var localFileDirty:Boolean;
	public function loadAndWatchExtensionFile(ext:ScratchExtension = null):void {
		if(localExt || localFilePoller > 0) {
			var msg:String = 'Sorry, a new extension cannot be created while another extension is connected to a file. ' +
					'Please save the project and disconnect from ' + localFileRef.name + ' first.';
			DialogBox.notify('Extensions', msg);
			return;
		}

		var filter:FileFilter = new FileFilter('Scratch 2.0 Javascript Extension', '*.js');
		var self:ExtensionDevManager = this;
		Scratch.loadSingleFile(function(e:Event):void {
			FileReference(e.target).removeEventListener(Event.COMPLETE, arguments.callee);
			FileReference(e.target).addEventListener(Event.COMPLETE, self.extensionFileLoaded);
			self.localExt = ext;
			self.extensionFileLoaded(e);
		}, [filter]);
	}

	public function stopWatchingExtensionFile():void {
		if(localFilePoller>0) clearInterval(localFilePoller);
		localExt = null;
		localFilePoller = 0;
		localFileDirty = false;
		localFileRef = null;
		localExtSaved = true;
		localExtCodeDate = null;
		app.updatePalette();
	}

	private var localExtCodeDate:Date = null;
	private function extensionFileLoaded(e:Event):void {
		localFileRef = FileReference(e.target);
		var lastModified:Date = localFileRef.modificationDate;
		var self:ExtensionDevManager = this;
		localFilePoller = setInterval(function():void {
			if(lastModified.getTime() != self.localFileRef.modificationDate.getTime()) {
				lastModified = self.localFileRef.modificationDate;
				self.localFileDirty = true;
				clearInterval(self.localFilePoller);
				// Shutdown the extension
				self.localFileRef.load();
			}
		}, 200);

		if(localFileDirty && localExt) {
			//DialogBox.confirm('Reload the "' + localExt.name + '" from ' + localFileRef.name + '?', null, loadLocalCode);
			app.updatePalette();
		}
		else
			loadLocalCode();
	}

	public function getLocalCodeDate():Date {
		return localExtCodeDate;
	}

	public function loadLocalCode(db:DialogBox = null):void {
		Scratch.app.runtime.stopAll();

		if(localExt) app.externalCall('ScratchExtensions.unregister', null, localExt.name);

		localFileDirty = false;
		rawExtensionLoaded = false;
		localExtCodeDate = localFileRef.modificationDate;
		app.externalCall('ScratchExtensions.loadLocalJS', null, localFileRef.data.toString());
//		if(!rawExtensionLoaded)
//			DialogBox.notify('Extensions', 'There was a problem loading your extension code. Please check your javascript console and fix the code.');

		app.updatePalette();
	}

	override public function setEnabled(extName:String, flag:Boolean):void {
		var ext:ScratchExtension = extensionDict[extName];
		if(ext && localExt === ext && !flag) {
			stopWatchingExtensionFile();
		}

		super.setEnabled(extName, flag);
	}
}}
