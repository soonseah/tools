////////////////////////////////////////////////////////////////////////////////
//
//  ADOBE SYSTEMS INCORPORATED
//  Copyright 2009 Adobe Systems Incorporated
//  All Rights Reserved.
//
//  NOTICE: Adobe permits you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////

package mx.core
{

import flash.display.DisplayObject;
import flash.display.DisplayObjectContainer;
import flash.display.Sprite;
import flash.events.Event;
import flash.geom.Matrix;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextLineMetrics;
import flashx.textLayout.compose.ISWFContext;
import flashx.textLayout.elements.GlobalSettings;
import mx.automation.IAutomationObject;
import mx.core.FTETextField;
import mx.managers.ISystemManager;
import mx.managers.IToolTipManagerClient;
import mx.managers.SystemManager;
import mx.managers.ToolTipManager;
import mx.resources.IResourceManager;
import mx.resources.ResourceManager;
import mx.styles.ISimpleStyleClient;
import mx.styles.IStyleClient;
import mx.styles.IStyleManager2;
import mx.styles.StyleManager;
import mx.styles.StyleProtoChain;
import mx.utils.NameUtil;
import mx.utils.StringUtil;
import spark.utils.TextUtil;

use namespace mx_internal;

//include "../styles/metadata/LeadingStyle.as"
//include "../styles/metadata/PaddingStyles.as"
//include "../styles/metadata/TextStyles.as"

[ResourceBundle("core")]
    
/**
 *  The UIFTETextField class is an alternative to the UITextField class
 *  for displaying text in MX components.
 *
 *  <p>UIFTETextField extends FTETextField in the same way
 *  that UITextField extends TextField.
 *  By extending FTETextField, it makes it possible
 *  for MX components to use the Flash Text Engine.
 *  Benefits of using FTE over TextField include
 *  higher-quality typography, bidirectional text, and rotatable text.</p>
 *
 *  <p>When MX components use FTE, they can use the same
 *  embedded fonts as Spark components, which always use FTE.
 *  Otherwise, a font must be embedded with <code>embedAsCFF="false"</code>
 *  for use by TextField-based components, and with
 *  <code>embedAsCFF="true"</code> for use by FTE-based components.</p>
 *
 *  <p>MX components that display text use the <code>textFieldClass</code>
 *  style to determine whether to create instances
 *  of UITextField or UIFTETextField.
 *  They are able to use either class because both classes implement
 *  the IUITextField interface.</p>
 * 
 *  <p>Warning: if UIFTETextField inherits <code>layoutDirection="rtl"</code>, it 
 *  will modify its own <code>transform.matrix</code> to restore the default
 *  coordinate system locally.</p>
 *
 *  @see mx.core.UITextField
 *  @see mx.core.FTETextField
 *  
 *  @langversion 3.0
 *  @playerversion Flash 10
 *  @playerversion AIR 1.5
 *  @productversion Flex 4
 */
public class UIFTETextField extends FTETextField
                            implements IAutomationObject, IIMESupport,
                            IFlexModule,
                            IInvalidating, ISimpleStyleClient,
                            IToolTipManagerClient, IUITextField
       
{
    include "../../spark/core/Version.as";

    //--------------------------------------------------------------------------
    //
    //  Implementation notes
    //
    //--------------------------------------------------------------------------

    /*

        UITextField extends the Player's TextField class,
        so here are some notes about TextField.

        The property values of a new TextField are as follows:

            alwaysShowSelection = false
            autoSize = TextFieldAutoSize.NONE
            background = false
            backgroundColor = 0xFFFFFF
            border = false
            borderColor = 0x000000
            caretIndex = 0
            condenseWhite = false
            displayAsPassword = false
            embedFonts = false
            height = 100
            htmlText = ""
            length = 0
            maxChars = 0
            mouseWheelEnabled = true
            multiline = false
            numLines = 1
            restrict = null
            selectable = true
            selectionBeginIndex = 0
            selectionEndIndex = 0
            text = ""
            textColor = 0x000000
            textHeight = 0
            textWidth = 0
            type = TextFieldType.DYNAMIC
            width = 100
            wordWrap = false
                
        Many of these properties are coupled.
        For example, setting 'text' affects 'htmlText', 'length',
        'textWidth', and 'textHeight'.
        If 'autoSize' isn't "none", it also affects 'width' and 'height'.

        The 'htmlText' getter and setter aren't symmetrical;
        if you set it and then get it, you don't get what you just set;
        you'll get additional HTML markup corresponding to the
        defaultTextFormat.

        If you set both the 'text' and the 'htmlText' properties
        of a TextField, the last one set wins.

        These setters do a lot of work; for example, suppose you set the 'text'.
        If it is an autosizing TextField, it computes the new width and height.
        If it is a wordwrapping TextField, it computes the appropriate line
        breaks.

        If you then get the 'text' property, it is what you just set.
        If you get the 'length', it is the length of the 'text' string.
        If you get the 'htmlText', it will contain a lot of autogenerated
        HTML markup corresponding to the defaultTextFormat, which was applied
        as a run across the entire new text.

        Now suppose you set the 'htmlText' property.
        The Player parses the string, separating the text characters
        from the markup.
        It first applies the defaultTextFormat as a run across the entire new
        text; it then uses the markup to modify this TextFormat or create
        additional TextFormat runs.
        When it's done it discards the 'htmlText' string that you set.
        
        If you then get the 'htmlText', it will not be what you just set; it
        will contain additional HTML markup corresponding to defaultTextFormat
        If you get the 'text', it will be text characters in the 'htmlText',
        without any of the HTML markup.
        If you get the 'length', it is the length of the 'text' string.

        If you set a TextFormat run with setTextFormat(), it will change the
        runs created from the HTML markup in the 'htmlText' that was last set.
        This is why, in the validateNow() method in UITextField, the original
        'htmlText' is reapplied after the TextFormat is changed.
    
        The 'condenseWhite' property only applies when setting 'htmlText',
        not 'text'.
        Changing 'condenseWhite' after setting 'htmlText' doesn't affect
        anything except future settings of 'htmlText'.
        
        The width and height of the TextField are 4 pixels greater than
        the textWidth and textHeight.
    
    */

    //--------------------------------------------------------------------------
    //
    //  Class constants
    //
    //--------------------------------------------------------------------------

    /**
     *  @private
     *  The padding to be added to textWidth to get the width
     *  of a TextField that can display the text without clipping.
     */ 
    mx_internal static const TEXT_WIDTH_PADDING:int = 5;

    /**
     *  @private
     *  The padding to be added to textHeight to get the height
     *  of a TextField that can display the text without clipping.
     */ 
    mx_internal static const TEXT_HEIGHT_PADDING:int = 4;

    //--------------------------------------------------------------------------
    //
    //  Class variables
    //
    //--------------------------------------------------------------------------

    /**
     *  @private
     *  Most resources are fetched on the fly from the ResourceManager,
     *  so they automatically get the right resource when the locale changes.
     *  But since truncateToFit() can be called frequently,
     *  this class caches this resource value in this variable
     *  and updates it when the locale changes.
     */ 
    private static var truncationIndicatorResource:String;

    /**
     *  @private
     */
    mx_internal static var debuggingBorders:Boolean = false;
    
    //--------------------------------------------------------------------------
    //
    //  Class properties
    //
    //--------------------------------------------------------------------------

    //----------------------------------
    //  embeddedFontRegistry
    //----------------------------------

    /**
     *  @private
     *  Storage for the _embeddedFontRegistry property.
     *  Note: This gets initialized on first access,
     *  not when this class is initialized, in order to ensure
     *  that the Singleton registry has already been initialized.
     */
    private static var _embeddedFontRegistry:IEmbeddedFontRegistry;

    /**
     *  @private
     *  A reference to the embedded font registry.
     *  Single registry in the system.
     *  Used to look up the moduleFactory of a font.
     */
    private static function get embeddedFontRegistry():IEmbeddedFontRegistry
    {
        if (!_embeddedFontRegistry)
        {
            _embeddedFontRegistry = IEmbeddedFontRegistry(
                Singleton.getInstance("mx.core::IEmbeddedFontRegistry"));
        }

        return _embeddedFontRegistry;
    }

    //--------------------------------------------------------------------------
    //
    //  Constructor
    //
    //--------------------------------------------------------------------------

    /**
     *  Constructor.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function UIFTETextField()
    {
        super();

		/**
		 *  Set the TLF hook used for localizing runtime error messages.
		 *  TLF itself has English-only messages,
		 *  but higher layers like Flex can provide localized versions.
		 */
		GlobalSettings.resourceStringFunction = TextUtil.getResourceString;
		
        // Although a TextField's 'text' is initially "",
        // getLineMetrics() will return bad values until some text is set.
        super.text = "";

        focusRect = false;
        selectable = false;
        tabEnabled = false;
         
        if (debuggingBorders)
            border = true;
         
        if (!truncationIndicatorResource)
        {
            truncationIndicatorResource = resourceManager.getString(
                "core", "truncationIndicator");
        }
        
        addEventListener(Event.CHANGE, changeHandler);
        addEventListener("textFieldStyleChange", textFieldStyleChangeHandler);
        
        // Register as a weak listener for "change" events from ResourceManager.
        // If UITextFields registered as a strong listener,
        // they wouldn't get garbage collected.
        resourceManager.addEventListener(
            Event.CHANGE, resourceManager_changeHandler, false, 0, true);
    }

    //--------------------------------------------------------------------------
    //
    //  Variables
    //
    //--------------------------------------------------------------------------

    /**
     *  @private
     *  Cached value of the TextFormat read from the Styles.
     */
    private var cachedTextFormat:TextFormat;

    /**
     * @private
     * 
     * Cache last value of embedded font.
     */
    private var cachedEmbeddedFont:EmbeddedFont = null;
     
    /**
     *  @private
     */
    private var invalidateDisplayListFlag:Boolean = true;

    /**
     *  @private
     */
    mx_internal var styleChangedFlag:Boolean = true;

    /**
     *  @private
     *  This var is either the last value of 'htmlText' that was set
     *  or null (if 'text' was set instead of 'htmlText').
     *
     *  This var is different from getting the 'htmlText',
     *  because when you set 'htmlText' into a TextField and then get it,
     *  you don't get what you set; what you get includes additional
     *  HTML markup generated from the defaultTextFormat
     *  (which for a Flex component is based on the CSS styles).
     *
     *  When you set 'htmlText', a TextField parses through it
     *  and creates TextFormat runs based on the HTML markup.
     *  It applies these on top of the defaultTextFormat.
     *  A TextField saves the non-markup characters as the 'text',
     *  but it doesn't save the original 'htmlText',
     *  so we have to do this ourselves.
     *
     *  If the CSS styles change, validateNow() will get called
     *  and a new TextFormat based on the new CSS styles
     *  will get applied to the entire TextField, wiping
     *  out any TextFormats that came from the HTML markup.
     *  So we use this var to re-apply the original markup
     *  after a CSS change.
     */
    private var explicitHTMLText:String = null;

    /**
     *  @private
     *  Color set explicitly by setColor(); overrides style lookup.
     */
    mx_internal var explicitColor:uint = StyleManager.NOT_A_COLOR;

    /**
     *  @private
     */
    private var resourceManager:IResourceManager =
                                    ResourceManager.getInstance();

    /**
     *  @private
     */
    private var untruncatedText:String;
    
    /**
     *  @private
     *  True if we've inherited layoutDirection="rtl".  
     */
    private var mirror:Boolean = false;

    //--------------------------------------------------------------------------
    //
    //  Overridden properties
    //
    //--------------------------------------------------------------------------
    
    //----------------------------------
    //  x
    //----------------------------------
    
    private var _x:Number = 0;
    
    /**
     *  @private
     */
    override public function set x(value:Number):void
    {
        _x = value;
        super.x = value;
        if (mirror)
            validateTransformMatrix();
    }
    
    /**
     *  @private
     */
    override public function get x():Number
    {
        // TODO(hmuller): by default get x returns transform.matrix.tx rounded to the nearest 20th.
        // should do the same here, if we're returning _x.
        return (mirror) ? _x : super.x;
    }
    
    //----------------------------------
    //  width
    //----------------------------------
    
    /**
     *  @private
     */
    override public function set width(value:Number):void  
    {
        super.width = value;
        if (mirror)
            validateTransformMatrix();
    }
    
    
    //----------------------------------
    //  htmlText
    //----------------------------------

    /**
     *  @private
     */
    override public function set htmlText(value:String):void
    {
        // TextField's htmlText property can't be set to null.
        if (!value)
            value = "";

        // Performance optimization: if the htmlText hasn't changed,
        // don't let the player think that we're dirty.
        if (isHTML && super.htmlText == value)
            return;

        // Reapply the format because TextField would otherwise reset to
        // black, Times New Roman, 12
        if (cachedTextFormat && styleSheet == null)
            defaultTextFormat = cachedTextFormat;
            
        super.htmlText = value;

        // Remember the htmlText that we've set,
        // because the TextField doesn't remember it for us.
        // We need it so that we can re-apply the HTML markup
        // in validateNow() after the CSS styles change
        explicitHTMLText = value;

        if (invalidateDisplayListFlag)
            validateNow();
    }

    //----------------------------------
    //  parent
    //----------------------------------

    /**
     *  @private
     *  Reference to this component's virtual parent container.
     *  "Virtual" means that this parent may not be the same
     *  as the one that the Player returns as the 'parent'
     *  property of a DisplayObject.
     *  For example, if a Container has created a contentPane
     *  to improve scrolling performance,
     *  then its "children" are really its grandchildren
     *  and their "parent" is actually their grandparent,
     *  because we don't want developers to be concerned with
     *  whether a contentPane exists or not.
     */
    mx_internal var _parent:DisplayObjectContainer;

    /**
     *  The parent container or component for this component.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    override public function get parent():DisplayObjectContainer
    {
        // Flash PlaceObject tags can have super.parent set
        // before we get to setting the _parent property.
        return _parent ? _parent : super.parent;
    }

    //----------------------------------
    //  text
    //----------------------------------

    /**
     *  @private
     */
    override public function set text(value:String):void
    {
        // TextField's text property can't be set to null.
        if (!value)
            value = "";
        
        // Performance optimization: if the text hasn't changed,
        // don't let the player think that we're dirty.
        if (!isHTML && super.text == value)
            return;

        super.text = value;

        explicitHTMLText = null;

        if (invalidateDisplayListFlag)
            validateNow();
    }

	//----------------------------------
	//  textColor
	//----------------------------------

	/**
	 *  @private
	 */
	override public function set textColor(value:uint):void
	{
		setColor(value);
	}
	
    //--------------------------------------------------------------------------
    //
    //  Properties
    //
    //--------------------------------------------------------------------------
    
    //----------------------------------
    //  automationDelegate
    //----------------------------------
    
    /**
     *  @private
     */
    private var _automationDelegate:IAutomationObject;

    /**
     *  The delegate object which is handling the automation related functionality.
     * 
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get automationDelegate():Object
    {
        return _automationDelegate;
    }

    /**
     *  @private
     */
    public function set automationDelegate(value:Object):void
    {
        _automationDelegate = value as IAutomationObject;
    }

    //----------------------------------
    //  automationName
    //----------------------------------

    /**
     *  @private
     *  Storage for the automationName property.
     */
    private var _automationName:String;

    /**
     *  @inheritDoc
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get automationName():String
    {
        if (_automationName)
            return _automationName; 
        if (automationDelegate)
            return automationDelegate.automationName;
        
        return "";
    }

    /**
     * @private
     */
    public function set automationName(value:String):void
    {
        _automationName = value;
    }

    /**
     *  @inheritDoc
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get automationValue():Array
    {
        if (automationDelegate)
           return automationDelegate.automationValue;
        
        return [""];
    }
	
    //----------------------------------
    //  automationOwner
    //----------------------------------
    
    /**
     *  @inheritDoc
     *  
     *  @langversion 3.0
     *  @playerversion Flash 9
     *  @playerversion AIR 1.1
     *  @productversion Flex 4
     */
    public function get automationOwner():DisplayObjectContainer
    {
        return owner;
    }
    
    //----------------------------------
    //  automationParent
    //----------------------------------
    
    /**
     *  @inheritDoc
     *  
     *  @langversion 3.0
     *  @playerversion Flash 9
     *  @playerversion AIR 1.1
     *  @productversion Flex 4
     */
    public function get automationParent():DisplayObjectContainer
    {
        return parent;
    }
    
    //----------------------------------
    //  automationEnabled
    //----------------------------------
    
    /**
     *  @inheritDoc
     *  
     *  @langversion 3.0
     *  @playerversion Flash 9
     *  @playerversion AIR 1.1
     *  @productversion Flex 4
     */
    public function get automationEnabled():Boolean
    {
        return enabled;
    }
    
    //----------------------------------
    //  automationVisible
    //----------------------------------
    
    /**
     *  @inheritDoc
     *  
     *  @langversion 3.0
     *  @playerversion Flash 9
     *  @playerversion AIR 1.1
     *  @productversion Flex 4
     */
    public function get automationVisible():Boolean
    {
        return visible;
    }

    //----------------------------------
    //  baselinePosition
    //----------------------------------

    /**
     *  The y-coordinate of the baseline of the first line of text.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get baselinePosition():Number
    {
        var tlm:TextLineMetrics;
        
        // The text styles aren't known until there is a parent.
        if (!parent)
            return NaN;
            
        // Ensure a textLine gets created.  Either a width and height must
        // be set or autoSize.
        var oldAutoSize:String;       
        if (autoSize == TextFieldAutoSize.NONE && (width == 0 || height == 0))
        {
            oldAutoSize = autoSize;
            autoSize = TextFieldAutoSize.LEFT;
        }
        
        // getLineMetrics() returns strange numbers for an empty string,
        // so instead we get the metrics for a non-empty string.
        var isEmpty:Boolean = text == "";
        if (isEmpty)
            super.text = "Wj";
        
       tlm = getLineMetrics(0);

       // Restore values.
       if (isEmpty)
            super.text = "";

        if (oldAutoSize != null)
            autoSize = oldAutoSize;
            
        // TextFields have 2 pixels of padding all around.
        return 2 + tlm.ascent;
    }
    
    //----------------------------------
    //  className
    //----------------------------------

    /**
     *  The name of this instance's class, such as
     *  <code>"DataGridItemRenderer"</code>.
     *
     *  <p>This string does not include the package name.
     *  If you need the package name as well, call the
     *  <code>getQualifiedClassName()</code> method in the flash.utils package.
     *  It will return a string such as
     *  <code>"mx.controls.dataGridClasses::DataGridItemRenderer"</code>.</p>
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get className():String
    {
        return NameUtil.getUnqualifiedClassName(this);
    }

    //----------------------------------
    //  document
    //----------------------------------

    /**
     *  @private
     *  Storage for the enabled property.
     */
    private var _document:Object;

    /**
     *  A reference to the document object associated with this UITextField object. 
     *  A document object is an Object at the top of the hierarchy of an application, 
     *  MXML component, or ActionScript component.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get document():Object
    {
        return _document;
    }

    /**
     *  @private
     */
    public function set document(value:Object):void
    {
        _document = value;
    }

    //----------------------------------
    //  enableIME
    //----------------------------------

    /**
     *  A flag that indicates whether the IME should
     *  be enabled when the component receives focus.
     *
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get enableIME():Boolean
    {
        return type == TextFieldType.INPUT;
    }

    //----------------------------------
    //  enabled
    //----------------------------------

    /**
     *  @private
     *  Storage for the enabled property.
     */
    private var _enabled:Boolean = true;

    /**
     *  A Boolean value that indicates whether the component is enabled. 
     *  This property only affects
     *  the color of the text and not whether the UITextField is editable.
     *  To control editability, use the 
     *  <code>flash.text.TextField.type</code> property.
     *  
     *  @default true
     *  @see flash.text.TextField
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get enabled():Boolean
    {
        return _enabled;
    }

    /**
     *  @private
     */
    public function set enabled(value:Boolean):void
    {
        mouseEnabled = value;
        _enabled = value;

        styleChanged("color");
    }

    //----------------------------------
    //  explicitHeight
    //----------------------------------

    /**
     *  @private
     *  Storage for the explicitHeight property.
     */
    private var _explicitHeight:Number;

    /**
     *  @copy mx.core.UIComponent#explicitHeight
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get explicitHeight():Number
    {
        return _explicitHeight;
    }

    /**
     *  @private
     */
    public function set explicitHeight(value:Number):void
    {
        _explicitHeight = value;
    }

    //----------------------------------
    //  explicitMaxHeight
    //----------------------------------

    /**
     *  Number that specifies the maximum height of the component, 
     *  in pixels, in the component's coordinates, if the maxHeight property
     *  is set. Because maxHeight is read-only, this method returns NaN. 
     *  You must override this method and add a setter to use this
     *  property.
     *  
     *  @see mx.core.UIComponent#explicitMaxHeight
     *  
     *  @default NaN
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get explicitMaxHeight():Number
    {
        return NaN;
    }

    //----------------------------------
    //  explicitMaxWidth
    //----------------------------------

    /**
     *  Number that specifies the maximum width of the component, 
     *  in pixels, in the component's coordinates, if the <code>maxWidth</code> property
     *  is set. Because the <code>maxWidth</code> property is read-only, this method returns <code>NaN</code>. 
     *  You must override this method and add a setter to use this
     *  property.
     *  
     *  @see mx.core.UIComponent#explicitMaxWidth
     *  
     *  @default NaN
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get explicitMaxWidth():Number
    {
        return NaN;
    }

    //----------------------------------
    //  explicitMinHeight
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#explicitMinHeight
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get explicitMinHeight():Number
    {
        return NaN;
    }

    //----------------------------------
    //  explicitMinWidth
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#explicitMinWidth
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get explicitMinWidth():Number
    {
        return NaN;
    }

    //----------------------------------
    //  explicitWidth
    //----------------------------------

    /**
     *  @private
     *  Storage for the explicitWidth property.
     */
    private var _explicitWidth:Number;

    /**
     *  @copy mx.core.UIComponent#explicitWidth
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get explicitWidth():Number
    {
        return _explicitWidth;
    }

    /**
     *  @private
     */
    public function set explicitWidth(value:Number):void
    {
        _explicitWidth = value;
    }

    //----------------------------------
    //  focusPane
    //----------------------------------

    /**
     *  @inheritDoc
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get focusPane():Sprite
    {
        return null;
    }

    /**
     *  @private
     */
    public function set focusPane(value:Sprite):void
    {
    }

    //----------------------------------
    //  ignorePadding
    //----------------------------------

    /**
     *  @private
     *  Storage for the ignorePadding property.
     */
    private var _ignorePadding:Boolean = true;

    /**
     *  If <code>true</code>, the <code>paddingLeft</code> and
     *  <code>paddingRight</code> styles will not add space
     *  around the text of the component.
     *  
     *  @default true
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get ignorePadding():Boolean
    {
        return _ignorePadding;
    }

    /**
     *  @private
     */
    public function set ignorePadding(value:Boolean):void
    {
        _ignorePadding = value;

        styleChanged(null);
    }

    //----------------------------------
    //  imeMode
    //----------------------------------

    /**
     *  @private
     *  Storage for the imeMode property.
     */
    private var _imeMode:String = null;

    /**
     *  Specifies the IME (input method editor) mode.
     *  The IME enables users to enter text in Chinese, Japanese, and Korean.
     *  Flex sets the specified IME mode when the control gets the focus,
     *  and sets it back to the previous value when the control loses the focus.
     *
     * <p>The flash.system.IMEConversionMode class defines constants for the
     *  valid values for this property.
     *  You can also specify <code>null</code> to specify no IME.</p>
     *
     *  @see flash.system.IMEConversionMode
     *
     *  @default null
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get imeMode():String
    {
        return _imeMode;
    }

    /**
     *  @private
     */
    public function set imeMode(value:String):void
    {
        _imeMode = value;
    }

    //----------------------------------
    //  includeInLayout
    //----------------------------------

    /**
     *  @private
     *  Storage for the includeInLayout property.
     */
    private var _includeInLayout:Boolean = true;

    /**
     *  @copy mx.core.UIComponent#includeInLayout
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get includeInLayout():Boolean
    {
        return _includeInLayout;
    }

    /**
     *  @private
     */
    public function set includeInLayout(value:Boolean):void
    {
        if (_includeInLayout != value)
        {
            _includeInLayout = value;

            var p:IInvalidating = parent as IInvalidating;
            if (p)
            {
                p.invalidateSize();
                p.invalidateDisplayList();
            }
        }
    }

    //----------------------------------
    //  inheritingStyles
    //----------------------------------

    /**
     *  @private
     *  Storage for the inheritingStyles property.
     */
    private var _inheritingStyles:Object = StyleProtoChain.STYLE_UNINITIALIZED;

    /**
     *  The beginning of this UITextField's chain of inheriting styles.
     *  The <code>getStyle()</code> method accesses
     *  <code>inheritingStyles[<i>styleName</i>]</code> to search the entire
     *  prototype-linked chain.
     *  This object is set up by the <code>initProtoChain()</code> method.
     *  You typically never need to access this property directly.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get inheritingStyles():Object
    {
        return _inheritingStyles;
    }

    /**
     *  @private
     */
    public function set inheritingStyles(value:Object):void
    {
        _inheritingStyles = value;
    }

    //----------------------------------
    //  initialized
    //----------------------------------

    /**
     *  @private
     *  Storage for the initialize property.
     */
    private var _initialized:Boolean = false;

    /**
     *  A flag that determines if an object has been through all three phases
     *  of layout validation (provided that any were required).
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get initialized():Boolean
    {
        return _initialized;
    }

    /**
     *  @private
     */
    public function set initialized(value:Boolean):void
    {
        _initialized = value;
    }

    //----------------------------------
    //  isHTML
    //----------------------------------

    /**
     *  @private
     */
    private function get isHTML():Boolean
    {
        return explicitHTMLText != null;
    }

    //----------------------------------
    //  isPopUp
    //----------------------------------
    /**
     *  @copy mx.core.UIComponent#isPopUp
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get isPopUp():Boolean
    {
    return false;
    }
    
    /**
     *  @private
     */
    public function set isPopUp(value:Boolean):void
    {
    }

    //----------------------------------
    //  maxHeight
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#maxHeight
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get maxHeight():Number
    {
        return UIComponent.DEFAULT_MAX_HEIGHT;
    }

    //----------------------------------
    //  maxWidth
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#maxWidth
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get maxWidth():Number
    {
        return UIComponent.DEFAULT_MAX_WIDTH;
    }

    //----------------------------------
    //  measuredHeight
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#measuredHeight
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get measuredHeight():Number
    {
        validateNow();
        
        return textHeight + TEXT_HEIGHT_PADDING;
    }

    //----------------------------------
    //  measuredMinHeight
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#measuredMinHeight
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get measuredMinHeight():Number
    {
        return 0;
    }

    /**
     *  @private
     */
    public function set measuredMinHeight(value:Number):void
    {
    }

    //----------------------------------
    //  measuredMinWidth
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#measuredMinWidth
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get measuredMinWidth():Number
    {
        return 0;
    }

    /**
     *  @private
     */
    public function set measuredMinWidth(value:Number):void
    {
    }

    //----------------------------------
    //  measuredWidth
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#measuredWidth
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get measuredWidth():Number
    {
        validateNow();
        
        return textWidth + TEXT_WIDTH_PADDING;
    }

    //----------------------------------
    //  minHeight
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#minHeight
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get minHeight():Number
    {
        return 0;
    }

    //----------------------------------
    //  minWidth
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#minWidth
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get minWidth():Number
    {
        return 0;
    }

    //----------------------------------
    //  moduleFactory
    //----------------------------------

    /**
     *  @private
     *  Storage for the moduleFactory property.
     */
    private var _moduleFactory:IFlexModuleFactory;
    
    [Inspectable(environment="none")]
    
    /**
     *  The moduleFactory that is used to create TextFields in the correct SWF context. This is necessary so that
     *  embedded fonts will work.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get moduleFactory():IFlexModuleFactory
    {
        return _moduleFactory;
    }

    /**
     *  @private
     */
    public function set moduleFactory(factory:IFlexModuleFactory):void
    {
        _moduleFactory = factory;
    }

    //----------------------------------
    //  nestLevel
    //----------------------------------

    /**
     *  @private
     *  Storage for the nestLevel property.
     */
    private var _nestLevel:int = 0;

    /**
     *  @copy mx.core.UIComponent#nestLevel
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get nestLevel():int
    {
        return _nestLevel;
    }
    
    /**
     *  @private
     */
    public function set nestLevel(value:int):void
    {
        // If my parent hasn't been attached to the display list, then its nestLevel
        // will be zero.  If it tries to set my nestLevel to 1, ignore it.  We'll
        // update nest levels again after the parent is added to the display list.
        //
        // Also punt if the new value for nestLevel is the same as my current value.
        if (value > 1 && _nestLevel != value)
        {
            _nestLevel = value;

            StyleProtoChain.initTextField(this);
            styleChangedFlag = true;
            validateNow();
        }
    }
    
    //----------------------------------
    //  nonInheritingStyles
    //----------------------------------

    /**
     *  @private
     *  Storage for the nonInheritingStyles property.
     */
    private var _nonInheritingStyles:Object = StyleProtoChain.STYLE_UNINITIALIZED;

    /**
     *  The beginning of this UITextField's chain of non-inheriting styles.
     *  The <code>getStyle()</code> method accesses
     *  <code>nonInheritingStyles[styleName]</code> method to search the entire
     *  prototype-linked chain.
     *  This object is set up by the <code>initProtoChain()</code> method.
     *  You typically never need to access this property directly.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get nonInheritingStyles():Object
    {
        return _nonInheritingStyles;
    }

    /**
     *  @private
     */
    public function set nonInheritingStyles(value:Object):void
    {
        _nonInheritingStyles = value;
    }

    //----------------------------------
    //  percentHeight
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#percentHeight
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get percentHeight():Number
    {
        return NaN;
    }

    /**
     *  @private
     */
     public function set percentHeight(value:Number):void
     {
     }

    //----------------------------------
    //  percentWidth
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#percentWidth
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get percentWidth():Number
    {
        return NaN;
    }

    /**
     *  @private
     */
     public function set percentWidth(value:Number):void
     {
     }

    //----------------------------------
    //  processedDescriptors
    //----------------------------------

    /**
     *  @private
     */
    private var _processedDescriptors:Boolean = true;

    /**
     *  Set to <code>true</code> after the <code>createChildren()</code>
     *  method creates any internal component children.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get processedDescriptors():Boolean
    {
        return _processedDescriptors;
    }

    /**
     *  @private
     */
    public function set processedDescriptors(value:Boolean):void
    {
        _processedDescriptors = value;
    }

    //----------------------------------
    //  styleManager
    //----------------------------------
    
    /**
     *  @private
     * 
     *  Returns the style manager used by this component.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get styleManager():IStyleManager2
    {
        return StyleManager.getStyleManager(moduleFactory);
    }
    
    //----------------------------------
    //  styleName
    //----------------------------------

    /**
     *  @private
     *  Storage for the styleName property.
     */
    private var _styleName:Object /* String, CSSStyleDeclaration, or UIComponent */;

    /**
     *  @copy mx.core.UIComponent#styleName
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get styleName():Object /* String, CSSStyleDeclaration, or UIComponent */
    {
        return _styleName;
    }

    /**
     *  @private
     */
    public function set styleName(value:Object /* String, CSSStyleDeclaration, or UIComponent */):void
    {
        if (_styleName === value)
            return;

        _styleName = value;

        if (parent)
        {
            StyleProtoChain.initTextField(this);
            styleChanged("styleName");
        }

        // If we don't have a parent pointer yet, then we'll wait
        // and initialize the proto chain when the parentChanged()
        // method is called.
    }

    //----------------------------------
    //  systemManager
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#systemManager
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get systemManager():ISystemManager
    {
        var o:DisplayObject = parent;
        while (o)
        {
            var ui:IUIComponent = o as IUIComponent;
            if (ui)
                return ui.systemManager;

            o = o.parent;
        }

        return null;
    }

    /**
     *  @private
     */
    public function set systemManager(value:ISystemManager):void
    {
        // Not supported
    }

    //----------------------------------
    //  nonZeroTextHeight
    //----------------------------------

    /**
     *  The height of the text, in pixels. Unlike the <code>textHeight</code> property,
     *  the <code>nonZeroTextHeight</code> property returns a non-zero value of what the 
     *  height of the text would be, even if the text is empty.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get nonZeroTextHeight():Number
    {
        if (super.text == "")
        {
            super.text = "Wj";
            var result:Number = textHeight;
            super.text = "";
            return result;
        }
        
        return textHeight;
    }
 
    //----------------------------------
    //  toolTip
    //----------------------------------

    /**
     *  @private
     *  Storage for the toolTip property.
     */
    mx_internal var _toolTip:String;

    /**
     *  @copy mx.core.UIComponent#toolTip
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get toolTip():String
    {
        return _toolTip;
    }

    /**
     *  @private
     */
    public function set toolTip(value:String):void
    {
        var oldValue:String = _toolTip;
        _toolTip = value;

        ToolTipManager.registerToolTip(this, oldValue, value);
    }

   //----------------------------------
    //  tweeningProperties
    //----------------------------------

    /**
     *  @copy mx.core.UIComponent#tweeningProperties
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get tweeningProperties():Array
    {
        return null;
    }

    /**
     *  @private
     */
    public function set tweeningProperties(value:Array):void
    {
    }

    //----------------------------------
    //  updateCompletePendingFlag
    //----------------------------------

    /**
     *  @private
     *  Storage for the updateCompletePendingFlag property.
     */
    private var _updateCompletePendingFlag:Boolean = false;

    /**
     *  A flag that determines if an object has been through all three phases
     *  of layout validation (provided that any were required)
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get updateCompletePendingFlag():Boolean
    {
        return _updateCompletePendingFlag;
    }

    /**
     *  @private
     */
    public function set updateCompletePendingFlag(value:Boolean):void
    {
        _updateCompletePendingFlag = value;
    }

    //--------------------------------------------------------------------------
    //
    //  Overridden methods: TextField
    //
    //--------------------------------------------------------------------------

    /**
     *  @private
     */
    override public function setTextFormat(format:TextFormat,
                                           beginIndex:int = -1,
                                           endIndex:int = -1):void
    {
        // It is an exception to call setTextFormat()
        // when styleSheet is applied.
        if (styleSheet)
            return;

        super.setTextFormat(format, beginIndex, endIndex);

        // Since changing the TextFormat will change the htmlText,
        // dispatch an event so that listeners can react to this.
        dispatchEvent(new Event("textFormatChange"));
    }   
    
    /**
     *  @private
     */
/*
    override public function insertXMLText(beginIndex:int, endIndex:int, 
                                           richText:String, 
                                           pasting:Boolean = false):void
    {
        super.insertXMLText(beginIndex, endIndex, richText, pasting);
        
        dispatchEvent(new Event("textInsert"));
    }
*/

    /**
     *  @private
     */
    override public function replaceText(beginIndex:int, endIndex:int,
                                         newText:String):void
    {
        super.replaceText(beginIndex, endIndex, newText);
        
        dispatchEvent(new Event("textReplace"));
    }
	
	/**
	 *  @private
	 */
	override mx_internal function getErrorMessage(key:String,
												  param:String = null):String
	{
		return resourceManager.getString("core", key, [ param ]);
	}

    //--------------------------------------------------------------------------
    //
    //  Methods
    //
    //--------------------------------------------------------------------------

    /**
     *  Initializes this component.
     *
     *  <p>This method is required by the IUIComponent interface,
     *  but it actually does nothing for a UITextField.</p>
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function initialize():void
    {
    }

    /**
     *  @copy mx.core.UIComponent#getExplicitOrMeasuredWidth()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function getExplicitOrMeasuredWidth():Number
    {
        return !isNaN(explicitWidth) ? explicitWidth : measuredWidth;
    }

    /**
     *  @copy mx.core.UIComponent#getExplicitOrMeasuredHeight()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function getExplicitOrMeasuredHeight():Number
    {
        return !isNaN(explicitHeight) ? explicitHeight : measuredHeight;
    }

    /**
     *  Sets the <code>visible</code> property of this UITextField object.
     * 
     *  @param visible <code>true</code> to make this UITextField visible, 
     *  and <code>false</code> to make it invisible.
     *
     *  @param noEvent <code>true</code> to suppress generating an event when you change visibility.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function setVisible(visible:Boolean, noEvent:Boolean = false):void
    {
        this.visible = visible
    }

    /**
     *  @copy mx.core.UIComponent#setFocus()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function setFocus():void
    {
        systemManager.stage.focus = this;
    }

    /**
     *  Returns a UITextFormat object that contains formatting information for this component. 
     *  This method is similar to the <code>getTextFormat()</code> method of the 
     *  flash.text.TextField class, but it returns a UITextFormat object instead 
     *  of a TextFormat object.
     *
     *  <p>The UITextFormat class extends the TextFormat class to add the text measurement methods
     *  <code>measureText()</code> and <code>measureHTMLText()</code>.</p>
     *
     *  @return An object that contains formatting information for this component.
     *
     *  @see mx.core.UITextFormat
     *  @see flash.text.TextField
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function getUITextFormat():UITextFormat
    {
        validateNow();
        
        var textFormat:UITextFormat = new UITextFormat(creatingSystemManager());
        textFormat.moduleFactory = moduleFactory;
        
        textFormat.copyFrom(getTextFormat());
        
        textFormat.antiAliasType = antiAliasType;
        textFormat.gridFitType = gridFitType;
        textFormat.sharpness = sharpness;
        textFormat.thickness = thickness;
        
        textFormat.useFTE = true;
        textFormat.direction = direction;
        textFormat.locale = locale;
        
        return textFormat;
    }

    /**
     *  @copy mx.core.UIComponent#move()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function move(x:Number, y:Number):void
    {
        // Performance optimization: if the position hasn't changed, don't let
        // the player think that we're dirty
        if (this.x != x)
            this.x = x;
        if (this.y != y)           
            this.y = y;
    }

    /**
     *  @copy mx.core.UIComponent#setActualSize()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function setActualSize(w:Number, h:Number):void
    {
        // Performance optimization: if the size hasn't changed, don't let
        // the player think that we're dirty
        if (width != w)
            width = w;
        if (height != h)
            height = h;
    }

    /**
     *  @copy mx.core.UIComponent#getStyle()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function getStyle(styleProp:String):*
    {
        if (styleManager.inheritingStyles[styleProp])
        {        
            return inheritingStyles ?
                   inheritingStyles[styleProp] :
                   IStyleClient(parent).getStyle(styleProp);
        }
        else
        {       
            return nonInheritingStyles ?
                   nonInheritingStyles[styleProp] :
                   IStyleClient(parent).getStyle(styleProp);
        }   
    }

    /**
     *  Does nothing.
     *  A UITextField cannot have inline styles.
     *
     *  @param styleProp n/a
     *
     *  @param newValue n/a
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function setStyle(styleProp:String, value:*):void
    {
    }

    /**
     *  This function is called when a UITextField object is assigned
     *  a parent.
     *  You typically never need to call this method.
     *
     *  @param p The parent of this UITextField object.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function parentChanged(p:DisplayObjectContainer):void
    {        
        if (!p)
        {
            _parent = null;
            _nestLevel = 0;
        }
        else if (p is IStyleClient)
        {
            _parent = p;
        }
        else if (p is SystemManager)
        {
            _parent = p;
        }
        else
        {
            _parent = p.parent;
        }
    }

    /**
     *  @copy mx.core.UIComponent#styleChanged()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function styleChanged(styleProp:String):void
    {
        styleChangedFlag = true;

        if (!invalidateDisplayListFlag)
        {
            invalidateDisplayListFlag = true;
            if ("callLater" in parent)
                Object(parent).callLater(validateNow);
        }
    }

    /**
     *  @copy mx.core.UIComponent#validateNow()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function validateNow():void
    {
        // If we don't have a parent pointer yet, then any attempts to get
        // style information will fail.  Do nothing now - this function will
        // be called again when parentChanged is called.
        if (!parent)
            return;

        // If mirroring, setting width can change the transform matrix.
        if (!isNaN(explicitWidth) && super.width != explicitWidth)
            width = (explicitWidth > 4) ? explicitWidth : 4;

        if (!isNaN(explicitHeight) && super.height != explicitHeight)
            super.height = explicitHeight;
        
        // If ancestor is mirroring, need to flip this so it is not
        // mirroring, by updating transform.matrix to compenstate for layout
        // mirroring.  layoutDirection should not be set directly on
        // UIFTETextField.
        if (styleChangedFlag)
        {
            const oldMirror:Boolean = mirror;
            mirror = getStyle("layoutDirection") == LayoutDirection.RTL;
            if (mirror || oldMirror)
                validateTransformMatrix();
        }

        // Set the text format.
        if (styleChangedFlag)
        {
            // direction is used by getTextStyles() so update it first.
            direction = getStyle("direction");
            locale = getStyle("locale");
            
            var textFormat:TextFormat = getTextStyles();
            if (textFormat.font)
            {
                var fontModuleFactory:IFlexModuleFactory = 
                    embeddedFontRegistry.getAssociatedModuleFactory(
                    textFormat.font, textFormat.bold, textFormat.italic,
                        this, moduleFactory, creatingSystemManager(), true);
    
                // if we found the font, then it is embedded. 
                // Some fonts are not listed in info(), so are not in the above registry.
                // Call isFontFaceEmbedded() which get the list of embedded fonts from the player.
                if (fontModuleFactory != null) 
                {
                    fontContext = fontModuleFactory;
                    embedFonts = true;
                }
            }
            else
            {
                embedFonts = getStyle("embedFonts");
                if (embedFonts)
                    fontContext = moduleFactory;
                else
                    fontContext = null;
            }

            if (getStyle("fontAntiAliasType") != undefined)
            {
                antiAliasType = getStyle("fontAntiAliasType");
                gridFitType = getStyle("fontGridFitType");
                sharpness = getStyle("fontSharpness");
                thickness = getStyle("fontThickness");
            }

            if (!styleSheet)
            {
                super.setTextFormat(textFormat);
                defaultTextFormat = textFormat;
            }
                    
            // Since changing the TextFormat will change the htmlText,
            // dispatch an event so that listeners can react to this.
            dispatchEvent(new Event("textFieldStyleChange"));
        }
        
        styleChangedFlag = false;
        invalidateDisplayListFlag = false;
    }
    
    /**
     *  @private
     *  Update the transform.matrix based on the mirror flag.  This method must be 
     *  called when x, width, or layoutDirection changes.
     */
    private function validateTransformMatrix():void
    {
        if (mirror)
        {
            const mirrorMatrix:Matrix = this.transform.matrix;
            mirrorMatrix.a = -1;
            mirrorMatrix.tx = _x + width;
            transform.matrix = mirrorMatrix;
        }
        else // layoutDirection changed, mirror=false, reset transform.matrix to its default
        {
            const defaultMatrix:Matrix = new Matrix();
            defaultMatrix.tx = _x;
            defaultMatrix.ty = y;
            transform.matrix = defaultMatrix;
        }
    }

    /**
     *  Returns the TextFormat object that represents 
     *  character formatting information for this UITextField object.
     *
     *  @return A TextFormat object. 
     *
     *  @see flash.text.TextFormat
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function getTextStyles():TextFormat
    {
        var textFormat:TextFormat = new TextFormat();

        var textAlign:String = getStyle("textAlign");
        // Map new Spark values that might be set in a selector
		// affecting both Halo and Spark components.
        if (textAlign == "start")
            textAlign = direction == "ltr" ? TextFormatAlign.LEFT : TextFormatAlign.RIGHT;
        else if (textAlign == "end")
            textAlign = direction == "ltr" ? TextFormatAlign.RIGHT : TextFormatAlign.LEFT;
        textFormat.align = textAlign; 
        textFormat.bold = getStyle("fontWeight") == "bold";
        if (enabled)
        {
            if (explicitColor == StyleManager.NOT_A_COLOR)
                textFormat.color = getStyle("color");
            else
                textFormat.color = explicitColor;
        }
        else
        {
            textFormat.color = getStyle("disabledColor");
        }
        textFormat.font = StringUtil.trimArrayElements(getStyle("fontFamily"),",");
        textFormat.indent = getStyle("textIndent");
        textFormat.italic = getStyle("fontStyle") == "italic";
		var kerning:* = getStyle("kerning");
		// In Halo components based on TextField,
		// kerning is supposed to be true or false.
		// The default in TextField and Flex 3 is false
		// because kerning doesn't work for device fonts
		// and is slow for embedded fonts.
		// In Spark components based on TLF and FTE,
		// kerning is "auto", "on", or, "off".
		// The default in TLF and FTE is "auto"
		// (which means kern non-Asian characters)
		// because kerning works even on device fonts
		// and has miminal performance impact.
        // Since a CSS selector or parent container
		// can affect both Halo and Spark components,
		// we need to map "auto" and "on" to true
		// and "off" to false for Halo components
		// here and in FTETextField.
		// For Spark components, Label and CSSTextLayoutFormat,
		// do the opposite mapping of true to "on" and false to "off".
		// We also support a value of "default"
		// (which we set in the global selector)
		// to mean false for Halo and "auto" for Spark,
		// to get the recommended behavior in both sets of components.
		if (kerning == "auto" || kerning == "on")
			kerning = true;
		else if (kerning == "default" || kerning == "off")
			kerning = false;
        textFormat.kerning = kerning;
        textFormat.leading = getStyle("leading");
        textFormat.leftMargin = ignorePadding ? 0 : getStyle("paddingLeft");
        textFormat.letterSpacing = getStyle("letterSpacing");
        textFormat.rightMargin = ignorePadding ? 0 : getStyle("paddingRight");
        textFormat.size = getStyle("fontSize");
        textFormat.underline = getStyle("textDecoration") == "underline";

        cachedTextFormat = textFormat;
        return textFormat;
    }

    /**
     *  Sets the font color of the text.
     *
     *  @param color The new font color.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function setColor(color:uint):void
    {
        explicitColor = color;
        styleChangedFlag = true;
        invalidateDisplayListFlag = true;
        
        validateNow();
    }

    /**
     *  @copy mx.core.UIComponent#invalidateSize()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function invalidateSize():void
    {
        invalidateDisplayListFlag = true;
    }

    /**
     *  @copy mx.core.UIComponent#invalidateDisplayList()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function invalidateDisplayList():void
    {
        invalidateDisplayListFlag = true;
    }

    /**
     *  @copy mx.core.UIComponent#invalidateProperties()
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function invalidateProperties():void
    {
    }
    
    /**
     *  Truncate text to make it fit horizontally in the area defined for the control, 
     *  and append an ellipsis, three periods (...), to the text.
     *
     *  @param truncationIndicator The text to be appended after truncation.
     *  If you pass <code>null</code>, a localizable string
     *  such as <code>"..."</code> will be used.
     *
     *  @return <code>true</code> if the text needed truncation.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function truncateToFit(truncationIndicator:String = null):Boolean
    {
        if (!truncationIndicator)
            truncationIndicator = truncationIndicatorResource;
                
        // Ensure that the proper CSS styles get applied to the textField
        // before measuring text.
        // Otherwise the callLater(validateNow) in styleChanged()
        // can apply the CSS styles too late.
        validateNow();
        
        var originalText:String = super.text;

        untruncatedText = originalText;

        var w:Number = width;

        // Need to check if we should truncate, but it 
        // could be due to rounding error.  Let's check that it's not.
        // Examples of rounding errors happen with "South Africa" and "Game"
        // with verdana.ttf.
        if (originalText != "" && textWidth + TEXT_WIDTH_PADDING > w + 0.00000000000001)
        {
            // This should get us into the ballpark.
            var s:String = super.text = originalText;
                originalText.slice(0,
                    Math.floor((w / (textWidth + TEXT_WIDTH_PADDING)) * originalText.length));

            while (s.length > 1 && textWidth + TEXT_WIDTH_PADDING > w)
            {
                s = s.slice(0, -1);
                super.text = s + truncationIndicator;
            }
            
            return true;
        }

        return false;
    }

    //--------------------------------------------------------------------------
    //
    //  Event handlers
    //
    //--------------------------------------------------------------------------

    /**
     *  @private
     */
    private function changeHandler(event:Event):void
    {
        // If the user changes the text displayed by the TextField,
        // whatever htmlText might have been set is now irrelevant.
        // This means that we can no longer re-apply any HTML markup
        // after a CSS style change.
        explicitHTMLText = null;
    }

    /**
     *  @private
     */
    private function textFieldStyleChangeHandler(event:Event):void
    {
        // Some TextFormat in the TextField just changed.
        // If the TextField is displaying htmlText we need
        // to reset the htmlText that was last set
        // so that its markup is applied on top of the new TextFormat.
        if (explicitHTMLText != null)
            super.htmlText = explicitHTMLText;
    }

    /**
     *  @private
     */
    private function resourceManager_changeHandler(event:Event):void
    {
        truncationIndicatorResource = resourceManager.getString(
            "core", "truncationIndicator");

        if (untruncatedText != null)
        {
            super.text = untruncatedText;
            truncateToFit();
        }
    }

    //--------------------------------------------------------------------------
    //
    //  IUIComponent
    //
    //--------------------------------------------------------------------------

    /**
     *  Returns <code>true</code> if the child is parented or owned by this object.
     *
     *  @param child The child DisplayObject.
     *
     *  @return <code>true</code> if the child is parented or owned by this UITextField object.
     * 
     *  @see #owner
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function owns(child:DisplayObject):Boolean
    {
        return child == this;
    }

    //----------------------------------
    //  owner
    //----------------------------------

    /**
     *  @private
     */
    private var _owner:DisplayObjectContainer;

    /**
     *  By default, set to the parent container of this object. 
     *  However, if this object is a child component that is 
     *  popped up by its parent, such as the dropdown list of a ComboBox control, 
     *  the owner is the component that popped up this object. 
     *
     *  <p>This property is not managed by Flex, but by each component. 
     *  Therefore, if you use the <code>PopUpManger.createPopUp()</code> or 
     *  <code>PopUpManger.addPopUp()</code> method to pop up a child component, 
     *  you should set the <code>owner</code> property of the child component 
     *  to the component that popped it up.</p>
     * 
     *  <p>The default value is the value of the <code>parent</code> property.</p>
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get owner():DisplayObjectContainer
    {
        return _owner ? _owner : parent;
    }

    public function set owner(value:DisplayObjectContainer):void
    {
        _owner = value;
    }

    private function creatingSystemManager():ISystemManager
    {
        return ((moduleFactory != null) && (moduleFactory is ISystemManager))
                ? ISystemManager(moduleFactory)
                : systemManager;
    }
    
    /**
     * @private
     * 
     * Get the embedded font for a set of font attributes.
     */ 
    private function getEmbeddedFont(fontName:String, bold:Boolean, italic:Boolean):EmbeddedFont
    {
        // Check if we can reuse a cached value.
        if (cachedEmbeddedFont)
        {
            if (cachedEmbeddedFont.fontName == fontName &&
                cachedEmbeddedFont.fontStyle == embeddedFontRegistry.getFontStyle(bold, italic))
            {
                return cachedEmbeddedFont;
            }   
        }
        
        cachedEmbeddedFont = new EmbeddedFont(fontName, bold, italic);      
        
        return cachedEmbeddedFont;
    }

    //----------------------------------
    //  IAutomationObject interface
    //----------------------------------

    /**
     *  @inheritDoc
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function replayAutomatableEvent(event:Event):Boolean
    {
        if (automationDelegate)
            return automationDelegate.replayAutomatableEvent(event);
        return false;
    }
    
    /**
     *  @private
     */
    public function createAutomationIDPart(child:IAutomationObject):Object
    {
        return null;
    }
    
    /**
     *  @private
     */
    public function createAutomationIDPartWithRequiredProperties(child:IAutomationObject, 
                                                                 properties:Array):Object
    {
        return null;
    }

    /**
     *  @private
     */
    public function resolveAutomationIDPart(criteria:Object):Array
    {
        return [];
    }
    
    /**
     *  @private
     */
    public function getAutomationChildAt(index:int):IAutomationObject
    {
        return null;
    }
    
    /**
     *  @private
     */
    public function getAutomationChildren():Array
    {
        return null;
    }
    
    /**
     *  @private
     */
    public function get numAutomationChildren():int
    {
        return 0;
    }
    
    /**
     *  @private
     */
    public function get showInAutomationHierarchy():Boolean
    {
        return true;
    }
    
    /**
     *  @private
     */
    public function set showInAutomationHierarchy(value:Boolean):void
    {
    }

    /**
     *  @private
     */
    public function get automationTabularData():Object
    {
        return null;
    }

}

}
