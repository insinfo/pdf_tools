// lib/src/libui_bindings.dart
// ignore_for_file: non_constant_identifier_names, camel_case_types

import 'dart:ffi';
import 'package:ffi/ffi.dart';

/// Carrega a biblioteca libui e expõe as funções C.
class LibUIBindings {
  final DynamicLibrary _lib;

  /// Carrega a biblioteca dinâmica.
  /// O caminho pode ser 'libui.dll' no Windows ou 'libui.so' no Linux.
  LibUIBindings(String path) : _lib = DynamicLibrary.open(path) {
    // Inicializa todos os lookups de função no construtor.
    // Isso garante que todas as funções sejam vinculadas quando a classe for instanciada.
    _initializeBindings();
  }

  // Declarações 'late final' para cada função da libui.
  // Elas serão inicializadas no método _initializeBindings.
  late final uiInit_dart uiInit;
  late final uiUninit_dart uiUninit;
  late final uiFreeInitError_dart uiFreeInitError;
  late final uiMain_dart uiMain;
  late final uiMainSteps_dart uiMainSteps;
  late final uiMainStep_dart uiMainStep;
  late final uiQuit_dart uiQuit;
  late final uiQueueMain_dart uiQueueMain;
  late final uiTimer_dart uiTimer;
  late final uiOnShouldQuit_dart uiOnShouldQuit;
  late final uiFreeText_dart uiFreeText;
  late final uiControlDestroy_dart uiControlDestroy;
  late final uiControlHandle_dart uiControlHandle;
  late final uiControlParent_dart uiControlParent;
  late final uiControlSetParent_dart uiControlSetParent;
  late final uiControlToplevel_dart uiControlToplevel;
  late final uiControlVisible_dart uiControlVisible;
  late final uiControlShow_dart uiControlShow;
  late final uiControlHide_dart uiControlHide;
  late final uiControlEnabled_dart uiControlEnabled;
  late final uiControlEnable_dart uiControlEnable;
  late final uiControlDisable_dart uiControlDisable;
  late final uiAllocControl_dart uiAllocControl;
  late final uiFreeControl_dart uiFreeControl;
  late final uiControlVerifySetParent_dart uiControlVerifySetParent;
  late final uiControlEnabledToUser_dart uiControlEnabledToUser;
  late final uiUserBugCannotSetParentOnToplevel_dart
      uiUserBugCannotSetParentOnToplevel;
  late final uiWindowTitle_dart uiWindowTitle;
  late final uiWindowSetTitle_dart uiWindowSetTitle;
  late final uiWindowPosition_dart uiWindowPosition;
  late final uiWindowSetPosition_dart uiWindowSetPosition;
  late final uiWindowOnPositionChanged_dart uiWindowOnPositionChanged;
  late final uiWindowContentSize_dart uiWindowContentSize;
  late final uiWindowSetContentSize_dart uiWindowSetContentSize;
  late final uiWindowFullscreen_dart uiWindowFullscreen;
  late final uiWindowSetFullscreen_dart uiWindowSetFullscreen;
  late final uiWindowOnContentSizeChanged_dart uiWindowOnContentSizeChanged;
  late final uiWindowOnClosing_dart uiWindowOnClosing;
  late final uiWindowOnFocusChanged_dart uiWindowOnFocusChanged;
  late final uiWindowFocused_dart uiWindowFocused;
  late final uiWindowBorderless_dart uiWindowBorderless;
  late final uiWindowSetBorderless_dart uiWindowSetBorderless;
  late final uiWindowSetChild_dart uiWindowSetChild;
  late final uiWindowMargined_dart uiWindowMargined;
  late final uiWindowSetMargined_dart uiWindowSetMargined;
  late final uiWindowResizeable_dart uiWindowResizeable;
  late final uiWindowSetResizeable_dart uiWindowSetResizeable;
  late final uiNewWindow_dart uiNewWindow;
  late final uiButtonText_dart uiButtonText;
  late final uiButtonSetText_dart uiButtonSetText;
  late final uiButtonOnClicked_dart uiButtonOnClicked;
  late final uiNewButton_dart uiNewButton;
  late final uiBoxAppend_dart uiBoxAppend;
  late final uiBoxNumChildren_dart uiBoxNumChildren;
  late final uiBoxDelete_dart uiBoxDelete;
  late final uiBoxPadded_dart uiBoxPadded;
  late final uiBoxSetPadded_dart uiBoxSetPadded;
  late final uiNewHorizontalBox_dart uiNewHorizontalBox;
  late final uiNewVerticalBox_dart uiNewVerticalBox;
  late final uiCheckboxText_dart uiCheckboxText;
  late final uiCheckboxSetText_dart uiCheckboxSetText;
  late final uiCheckboxOnToggled_dart uiCheckboxOnToggled;
  late final uiCheckboxChecked_dart uiCheckboxChecked;
  late final uiCheckboxSetChecked_dart uiCheckboxSetChecked;
  late final uiNewCheckbox_dart uiNewCheckbox;
  late final uiEntryText_dart uiEntryText;
  late final uiEntrySetText_dart uiEntrySetText;
  late final uiEntryOnChanged_dart uiEntryOnChanged;
  late final uiEntryReadOnly_dart uiEntryReadOnly;
  late final uiEntrySetReadOnly_dart uiEntrySetReadOnly;
  late final uiNewEntry_dart uiNewEntry;
  late final uiNewPasswordEntry_dart uiNewPasswordEntry;
  late final uiNewSearchEntry_dart uiNewSearchEntry;
  late final uiLabelText_dart uiLabelText;
  late final uiLabelSetText_dart uiLabelSetText;
  late final uiNewLabel_dart uiNewLabel;
  late final uiTabAppend_dart uiTabAppend;
  late final uiTabInsertAt_dart uiTabInsertAt;
  late final uiTabDelete_dart uiTabDelete;
  late final uiTabNumPages_dart uiTabNumPages;
  late final uiTabMargined_dart uiTabMargined;
  late final uiTabSetMargined_dart uiTabSetMargined;
  late final uiNewTab_dart uiNewTab;
  late final uiGroupTitle_dart uiGroupTitle;
  late final uiGroupSetTitle_dart uiGroupSetTitle;
  late final uiGroupSetChild_dart uiGroupSetChild;
  late final uiGroupMargined_dart uiGroupMargined;
  late final uiGroupSetMargined_dart uiGroupSetMargined;
  late final uiNewGroup_dart uiNewGroup;
  late final uiSpinboxValue_dart uiSpinboxValue;
  late final uiSpinboxSetValue_dart uiSpinboxSetValue;
  late final uiSpinboxOnChanged_dart uiSpinboxOnChanged;
  late final uiNewSpinbox_dart uiNewSpinbox;
  late final uiSliderValue_dart uiSliderValue;
  late final uiSliderSetValue_dart uiSliderSetValue;
  late final uiSliderHasToolTip_dart uiSliderHasToolTip;
  late final uiSliderSetHasToolTip_dart uiSliderSetHasToolTip;
  late final uiSliderOnChanged_dart uiSliderOnChanged;
  late final uiSliderOnReleased_dart uiSliderOnReleased;
  late final uiSliderSetRange_dart uiSliderSetRange;
  late final uiNewSlider_dart uiNewSlider;
  late final uiProgressBarValue_dart uiProgressBarValue;
  late final uiProgressBarSetValue_dart uiProgressBarSetValue;
  late final uiNewProgressBar_dart uiNewProgressBar;
  late final uiNewHorizontalSeparator_dart uiNewHorizontalSeparator;
  late final uiNewVerticalSeparator_dart uiNewVerticalSeparator;
  late final uiComboboxAppend_dart uiComboboxAppend;
  late final uiComboboxInsertAt_dart uiComboboxInsertAt;
  late final uiComboboxDelete_dart uiComboboxDelete;
  late final uiComboboxClear_dart uiComboboxClear;
  late final uiComboboxNumItems_dart uiComboboxNumItems;
  late final uiComboboxSelected_dart uiComboboxSelected;
  late final uiComboboxSetSelected_dart uiComboboxSetSelected;
  late final uiComboboxOnSelected_dart uiComboboxOnSelected;
  late final uiNewCombobox_dart uiNewCombobox;
  late final uiEditableComboboxAppend_dart uiEditableComboboxAppend;
  late final uiEditableComboboxText_dart uiEditableComboboxText;
  late final uiEditableComboboxSetText_dart uiEditableComboboxSetText;
  late final uiEditableComboboxOnChanged_dart uiEditableComboboxOnChanged;
  late final uiNewEditableCombobox_dart uiNewEditableCombobox;
  late final uiRadioButtonsAppend_dart uiRadioButtonsAppend;
  late final uiRadioButtonsSelected_dart uiRadioButtonsSelected;
  late final uiRadioButtonsSetSelected_dart uiRadioButtonsSetSelected;
  late final uiRadioButtonsOnSelected_dart uiRadioButtonsOnSelected;
  late final uiNewRadioButtons_dart uiNewRadioButtons;
  late final uiDateTimePickerTime_dart uiDateTimePickerTime;
  late final uiDateTimePickerSetTime_dart uiDateTimePickerSetTime;
  late final uiDateTimePickerOnChanged_dart uiDateTimePickerOnChanged;
  late final uiNewDateTimePicker_dart uiNewDateTimePicker;
  late final uiNewDatePicker_dart uiNewDatePicker;
  late final uiNewTimePicker_dart uiNewTimePicker;
  late final uiMultilineEntryText_dart uiMultilineEntryText;
  late final uiMultilineEntrySetText_dart uiMultilineEntrySetText;
  late final uiMultilineEntryAppend_dart uiMultilineEntryAppend;
  late final uiMultilineEntryOnChanged_dart uiMultilineEntryOnChanged;
  late final uiMultilineEntryReadOnly_dart uiMultilineEntryReadOnly;
  late final uiMultilineEntrySetReadOnly_dart uiMultilineEntrySetReadOnly;
  late final uiNewMultilineEntry_dart uiNewMultilineEntry;
  late final uiNewNonWrappingMultilineEntry_dart uiNewNonWrappingMultilineEntry;
  late final uiMenuItemEnable_dart uiMenuItemEnable;
  late final uiMenuItemDisable_dart uiMenuItemDisable;
  late final uiMenuItemOnClicked_dart uiMenuItemOnClicked;
  late final uiMenuItemChecked_dart uiMenuItemChecked;
  late final uiMenuItemSetChecked_dart uiMenuItemSetChecked;
  late final uiMenuAppendItem_dart uiMenuAppendItem;
  late final uiMenuAppendCheckItem_dart uiMenuAppendCheckItem;
  late final uiMenuAppendQuitItem_dart uiMenuAppendQuitItem;
  late final uiMenuAppendPreferencesItem_dart uiMenuAppendPreferencesItem;
  late final uiMenuAppendAboutItem_dart uiMenuAppendAboutItem;
  late final uiMenuAppendSeparator_dart uiMenuAppendSeparator;
  late final uiNewMenu_dart uiNewMenu;
  late final uiOpenFile_dart uiOpenFile;
  late final uiOpenFolder_dart uiOpenFolder;
  late final uiSaveFile_dart uiSaveFile;
  late final uiMsgBox_dart uiMsgBox;
  late final uiMsgBoxError_dart uiMsgBoxError;
  late final uiAreaSetSize_dart uiAreaSetSize;
  late final uiAreaQueueRedrawAll_dart uiAreaQueueRedrawAll;
  late final uiAreaScrollTo_dart uiAreaScrollTo;
  late final uiAreaBeginUserWindowMove_dart uiAreaBeginUserWindowMove;
  late final uiAreaBeginUserWindowResize_dart uiAreaBeginUserWindowResize;
  late final uiNewArea_dart uiNewArea;
  late final uiNewScrollingArea_dart uiNewScrollingArea;
  late final uiDrawNewPath_dart uiDrawNewPath;
  late final uiDrawFreePath_dart uiDrawFreePath;
  late final uiDrawPathNewFigure_dart uiDrawPathNewFigure;
  late final uiDrawPathNewFigureWithArc_dart uiDrawPathNewFigureWithArc;
  late final uiDrawPathLineTo_dart uiDrawPathLineTo;
  late final uiDrawPathArcTo_dart uiDrawPathArcTo;
  late final uiDrawPathBezierTo_dart uiDrawPathBezierTo;
  late final uiDrawPathCloseFigure_dart uiDrawPathCloseFigure;
  late final uiDrawPathAddRectangle_dart uiDrawPathAddRectangle;
  late final uiDrawPathEnded_dart uiDrawPathEnded;
  late final uiDrawPathEnd_dart uiDrawPathEnd;
  late final uiDrawStroke_dart uiDrawStroke;
  late final uiDrawFill_dart uiDrawFill;
  late final uiDrawMatrixSetIdentity_dart uiDrawMatrixSetIdentity;
  late final uiDrawMatrixTranslate_dart uiDrawMatrixTranslate;
  late final uiDrawMatrixScale_dart uiDrawMatrixScale;
  late final uiDrawMatrixRotate_dart uiDrawMatrixRotate;
  late final uiDrawMatrixSkew_dart uiDrawMatrixSkew;
  late final uiDrawMatrixMultiply_dart uiDrawMatrixMultiply;
  late final uiDrawMatrixInvertible_dart uiDrawMatrixInvertible;
  late final uiDrawMatrixInvert_dart uiDrawMatrixInvert;
  late final uiDrawMatrixTransformPoint_dart uiDrawMatrixTransformPoint;
  late final uiDrawMatrixTransformSize_dart uiDrawMatrixTransformSize;
  late final uiDrawTransform_dart uiDrawTransform;
  late final uiDrawClip_dart uiDrawClip;
  late final uiDrawSave_dart uiDrawSave;
  late final uiDrawRestore_dart uiDrawRestore;
  late final uiFreeAttribute_dart uiFreeAttribute;
  late final uiAttributeGetType_dart uiAttributeGetType;
  late final uiNewFamilyAttribute_dart uiNewFamilyAttribute;
  late final uiAttributeFamily_dart uiAttributeFamily;
  late final uiNewSizeAttribute_dart uiNewSizeAttribute;
  late final uiAttributeSize_dart uiAttributeSize;
  late final uiNewWeightAttribute_dart uiNewWeightAttribute;
  late final uiAttributeWeight_dart uiAttributeWeight;
  late final uiNewItalicAttribute_dart uiNewItalicAttribute;
  late final uiAttributeItalic_dart uiAttributeItalic;
  late final uiNewStretchAttribute_dart uiNewStretchAttribute;
  late final uiAttributeStretch_dart uiAttributeStretch;
  late final uiNewColorAttribute_dart uiNewColorAttribute;
  late final uiAttributeColor_dart uiAttributeColor;
  late final uiNewBackgroundAttribute_dart uiNewBackgroundAttribute;
  late final uiNewUnderlineAttribute_dart uiNewUnderlineAttribute;
  late final uiAttributeUnderline_dart uiAttributeUnderline;
  late final uiNewUnderlineColorAttribute_dart uiNewUnderlineColorAttribute;
  late final uiAttributeUnderlineColor_dart uiAttributeUnderlineColor;
  late final uiNewOpenTypeFeatures_dart uiNewOpenTypeFeatures;
  late final uiFreeOpenTypeFeatures_dart uiFreeOpenTypeFeatures;
  late final uiOpenTypeFeaturesClone_dart uiOpenTypeFeaturesClone;
  late final uiOpenTypeFeaturesAdd_dart uiOpenTypeFeaturesAdd;
  late final uiOpenTypeFeaturesRemove_dart uiOpenTypeFeaturesRemove;
  late final uiOpenTypeFeaturesGet_dart uiOpenTypeFeaturesGet;
  late final uiOpenTypeFeaturesForEach_dart uiOpenTypeFeaturesForEach;
  late final uiNewFeaturesAttribute_dart uiNewFeaturesAttribute;
  late final uiAttributeFeatures_dart uiAttributeFeatures;
  late final uiNewAttributedString_dart uiNewAttributedString;
  late final uiFreeAttributedString_dart uiFreeAttributedString;
  late final uiAttributedStringString_dart uiAttributedStringString;
  late final uiAttributedStringLen_dart uiAttributedStringLen;
  late final uiAttributedStringAppendUnattributed_dart
      uiAttributedStringAppendUnattributed;
  late final uiAttributedStringInsertAtUnattributed_dart
      uiAttributedStringInsertAtUnattributed;
  late final uiAttributedStringDelete_dart uiAttributedStringDelete;
  late final uiAttributedStringSetAttribute_dart uiAttributedStringSetAttribute;
  late final uiAttributedStringForEachAttribute_dart
      uiAttributedStringForEachAttribute;
  late final uiAttributedStringNumGraphemes_dart uiAttributedStringNumGraphemes;
  late final uiAttributedStringByteIndexToGrapheme_dart
      uiAttributedStringByteIndexToGrapheme;
  late final uiAttributedStringGraphemeToByteIndex_dart
      uiAttributedStringGraphemeToByteIndex;
  late final uiLoadControlFont_dart uiLoadControlFont;
  late final uiFreeFontDescriptor_dart uiFreeFontDescriptor;
  late final uiDrawNewTextLayout_dart uiDrawNewTextLayout;
  late final uiDrawFreeTextLayout_dart uiDrawFreeTextLayout;
  late final uiDrawText_dart uiDrawText;
  late final uiDrawTextLayoutExtents_dart uiDrawTextLayoutExtents;
  late final uiFontButtonFont_dart uiFontButtonFont;
  late final uiFontButtonOnChanged_dart uiFontButtonOnChanged;
  late final uiNewFontButton_dart uiNewFontButton;
  late final uiFreeFontButtonFont_dart uiFreeFontButtonFont;
  late final uiColorButtonColor_dart uiColorButtonColor;
  late final uiColorButtonSetColor_dart uiColorButtonSetColor;
  late final uiColorButtonOnChanged_dart uiColorButtonOnChanged;
  late final uiNewColorButton_dart uiNewColorButton;
  late final uiFormAppend_dart uiFormAppend;
  late final uiFormNumChildren_dart uiFormNumChildren;
  late final uiFormDelete_dart uiFormDelete;
  late final uiFormPadded_dart uiFormPadded;
  late final uiFormSetPadded_dart uiFormSetPadded;
  late final uiNewForm_dart uiNewForm;
  late final uiGridAppend_dart uiGridAppend;
  late final uiGridInsertAt_dart uiGridInsertAt;
  late final uiGridPadded_dart uiGridPadded;
  late final uiGridSetPadded_dart uiGridSetPadded;
  late final uiNewGrid_dart uiNewGrid;
  late final uiNewImage_dart uiNewImage;
  late final uiFreeImage_dart uiFreeImage;
  late final uiImageAppend_dart uiImageAppend;
  late final uiFreeTableValue_dart uiFreeTableValue;
  late final uiTableValueGetType_dart uiTableValueGetType;
  late final uiNewTableValueString_dart uiNewTableValueString;
  late final uiTableValueString_dart uiTableValueString;
  late final uiNewTableValueImage_dart uiNewTableValueImage;
  late final uiTableValueImage_dart uiTableValueImage;
  late final uiNewTableValueInt_dart uiNewTableValueInt;
  late final uiTableValueInt_dart uiTableValueInt;
  late final uiNewTableValueColor_dart uiNewTableValueColor;
  late final uiTableValueColor_dart uiTableValueColor;
  late final uiNewTableModel_dart uiNewTableModel;
  late final uiFreeTableModel_dart uiFreeTableModel;
  late final uiTableModelRowInserted_dart uiTableModelRowInserted;
  late final uiTableModelRowChanged_dart uiTableModelRowChanged;
  late final uiTableModelRowDeleted_dart uiTableModelRowDeleted;
  late final uiTableAppendTextColumn_dart uiTableAppendTextColumn;
  late final uiTableAppendImageColumn_dart uiTableAppendImageColumn;
  late final uiTableAppendImageTextColumn_dart uiTableAppendImageTextColumn;
  late final uiTableAppendCheckboxColumn_dart uiTableAppendCheckboxColumn;
  late final uiTableAppendCheckboxTextColumn_dart
      uiTableAppendCheckboxTextColumn;
  late final uiTableAppendProgressBarColumn_dart uiTableAppendProgressBarColumn;
  late final uiTableAppendButtonColumn_dart uiTableAppendButtonColumn;
  late final uiTableHeaderVisible_dart uiTableHeaderVisible;
  late final uiTableHeaderSetVisible_dart uiTableHeaderSetVisible;
  late final uiNewTable_dart uiNewTable;
  late final uiTableOnRowClicked_dart uiTableOnRowClicked;
  late final uiTableOnRowDoubleClicked_dart uiTableOnRowDoubleClicked;
  late final uiTableHeaderSetSortIndicator_dart uiTableHeaderSetSortIndicator;
  late final uiTableHeaderSortIndicator_dart uiTableHeaderSortIndicator;
  late final uiTableHeaderOnClicked_dart uiTableHeaderOnClicked;
  late final uiTableColumnWidth_dart uiTableColumnWidth;
  late final uiTableColumnSetWidth_dart uiTableColumnSetWidth;
  late final uiTableGetSelectionMode_dart uiTableGetSelectionMode;
  late final uiTableSetSelectionMode_dart uiTableSetSelectionMode;
  late final uiTableOnSelectionChanged_dart uiTableOnSelectionChanged;
  late final uiTableGetSelection_dart uiTableGetSelection;
  late final uiTableSetSelection_dart uiTableSetSelection;
  late final uiFreeTableSelection_dart uiFreeTableSelection;

  /// Método privado para carregar todas as funções da DLL.
  void _initializeBindings() {
    uiInit = _lib
        .lookup<NativeFunction<uiInit_native>>('uiInit')
        .asFunction<uiInit_dart>();
    uiUninit = _lib
        .lookup<NativeFunction<uiUninit_native>>('uiUninit')
        .asFunction<uiUninit_dart>();
    uiFreeInitError = _lib
        .lookup<NativeFunction<uiFreeInitError_native>>('uiFreeInitError')
        .asFunction<uiFreeInitError_dart>();
    uiMain =
        _lib.lookup<NativeFunction<uiMain_native>>('uiMain').asFunction<uiMain_dart>();
    uiMainSteps = _lib
        .lookup<NativeFunction<uiMainSteps_native>>('uiMainSteps')
        .asFunction<uiMainSteps_dart>();
    uiMainStep = _lib
        .lookup<NativeFunction<uiMainStep_native>>('uiMainStep')
        .asFunction<uiMainStep_dart>();
    uiQuit =
        _lib.lookup<NativeFunction<uiQuit_native>>('uiQuit').asFunction<uiQuit_dart>();
    uiQueueMain = _lib
        .lookup<NativeFunction<uiQueueMain_native>>('uiQueueMain')
        .asFunction<uiQueueMain_dart>();
    uiTimer =
        _lib.lookup<NativeFunction<uiTimer_native>>('uiTimer').asFunction<uiTimer_dart>();
    uiOnShouldQuit = _lib
        .lookup<NativeFunction<uiOnShouldQuit_native>>('uiOnShouldQuit')
        .asFunction<uiOnShouldQuit_dart>();
    uiFreeText = _lib
        .lookup<NativeFunction<uiFreeText_native>>('uiFreeText')
        .asFunction<uiFreeText_dart>();
    uiControlDestroy = _lib
        .lookup<NativeFunction<uiControlDestroy_native>>('uiControlDestroy')
        .asFunction<uiControlDestroy_dart>();
    uiControlHandle = _lib
        .lookup<NativeFunction<uiControlHandle_native>>('uiControlHandle')
        .asFunction<uiControlHandle_dart>();
    uiControlParent = _lib
        .lookup<NativeFunction<uiControlParent_native>>('uiControlParent')
        .asFunction<uiControlParent_dart>();
    uiControlSetParent = _lib
        .lookup<NativeFunction<uiControlSetParent_native>>(
            'uiControlSetParent')
        .asFunction<uiControlSetParent_dart>();
    uiControlToplevel = _lib
        .lookup<NativeFunction<uiControlToplevel_native>>('uiControlToplevel')
        .asFunction<uiControlToplevel_dart>();
    uiControlVisible = _lib
        .lookup<NativeFunction<uiControlVisible_native>>('uiControlVisible')
        .asFunction<uiControlVisible_dart>();
    uiControlShow = _lib
        .lookup<NativeFunction<uiControlShow_native>>('uiControlShow')
        .asFunction<uiControlShow_dart>();
    uiControlHide = _lib
        .lookup<NativeFunction<uiControlHide_native>>('uiControlHide')
        .asFunction<uiControlHide_dart>();
    uiControlEnabled = _lib
        .lookup<NativeFunction<uiControlEnabled_native>>('uiControlEnabled')
        .asFunction<uiControlEnabled_dart>();
    uiControlEnable = _lib
        .lookup<NativeFunction<uiControlEnable_native>>('uiControlEnable')
        .asFunction<uiControlEnable_dart>();
    uiControlDisable = _lib
        .lookup<NativeFunction<uiControlDisable_native>>('uiControlDisable')
        .asFunction<uiControlDisable_dart>();
    uiAllocControl = _lib
        .lookup<NativeFunction<uiAllocControl_native>>('uiAllocControl')
        .asFunction<uiAllocControl_dart>();
    uiFreeControl = _lib
        .lookup<NativeFunction<uiFreeControl_native>>('uiFreeControl')
        .asFunction<uiFreeControl_dart>();
    uiControlVerifySetParent = _lib
        .lookup<NativeFunction<uiControlVerifySetParent_native>>(
            'uiControlVerifySetParent')
        .asFunction<uiControlVerifySetParent_dart>();
    uiControlEnabledToUser = _lib
        .lookup<NativeFunction<uiControlEnabledToUser_native>>(
            'uiControlEnabledToUser')
        .asFunction<uiControlEnabledToUser_dart>();
    uiUserBugCannotSetParentOnToplevel = _lib
        .lookup<NativeFunction<uiUserBugCannotSetParentOnToplevel_native>>(
            'uiUserBugCannotSetParentOnToplevel')
        .asFunction<uiUserBugCannotSetParentOnToplevel_dart>();
    uiWindowTitle = _lib
        .lookup<NativeFunction<uiWindowTitle_native>>('uiWindowTitle')
        .asFunction<uiWindowTitle_dart>();
    uiWindowSetTitle = _lib
        .lookup<NativeFunction<uiWindowSetTitle_native>>('uiWindowSetTitle')
        .asFunction<uiWindowSetTitle_dart>();
    uiWindowPosition = _lib
        .lookup<NativeFunction<uiWindowPosition_native>>('uiWindowPosition')
        .asFunction<uiWindowPosition_dart>();
    uiWindowSetPosition = _lib
        .lookup<NativeFunction<uiWindowSetPosition_native>>(
            'uiWindowSetPosition')
        .asFunction<uiWindowSetPosition_dart>();
    uiWindowOnPositionChanged = _lib
        .lookup<NativeFunction<uiWindowOnPositionChanged_native>>(
            'uiWindowOnPositionChanged')
        .asFunction<uiWindowOnPositionChanged_dart>();
    uiWindowContentSize = _lib
        .lookup<NativeFunction<uiWindowContentSize_native>>(
            'uiWindowContentSize')
        .asFunction<uiWindowContentSize_dart>();
    uiWindowSetContentSize = _lib
        .lookup<NativeFunction<uiWindowSetContentSize_native>>(
            'uiWindowSetContentSize')
        .asFunction<uiWindowSetContentSize_dart>();
    uiWindowFullscreen = _lib
        .lookup<NativeFunction<uiWindowFullscreen_native>>(
            'uiWindowFullscreen')
        .asFunction<uiWindowFullscreen_dart>();
    uiWindowSetFullscreen = _lib
        .lookup<NativeFunction<uiWindowSetFullscreen_native>>(
            'uiWindowSetFullscreen')
        .asFunction<uiWindowSetFullscreen_dart>();
    uiWindowOnContentSizeChanged = _lib
        .lookup<NativeFunction<uiWindowOnContentSizeChanged_native>>(
            'uiWindowOnContentSizeChanged')
        .asFunction<uiWindowOnContentSizeChanged_dart>();
    uiWindowOnClosing = _lib
        .lookup<NativeFunction<uiWindowOnClosing_native>>('uiWindowOnClosing')
        .asFunction<uiWindowOnClosing_dart>();
    uiWindowOnFocusChanged = _lib
        .lookup<NativeFunction<uiWindowOnFocusChanged_native>>(
            'uiWindowOnFocusChanged')
        .asFunction<uiWindowOnFocusChanged_dart>();
    uiWindowFocused = _lib
        .lookup<NativeFunction<uiWindowFocused_native>>('uiWindowFocused')
        .asFunction<uiWindowFocused_dart>();
    uiWindowBorderless = _lib
        .lookup<NativeFunction<uiWindowBorderless_native>>(
            'uiWindowBorderless')
        .asFunction<uiWindowBorderless_dart>();
    uiWindowSetBorderless = _lib
        .lookup<NativeFunction<uiWindowSetBorderless_native>>(
            'uiWindowSetBorderless')
        .asFunction<uiWindowSetBorderless_dart>();
    uiWindowSetChild = _lib
        .lookup<NativeFunction<uiWindowSetChild_native>>('uiWindowSetChild')
        .asFunction<uiWindowSetChild_dart>();
    uiWindowMargined = _lib
        .lookup<NativeFunction<uiWindowMargined_native>>('uiWindowMargined')
        .asFunction<uiWindowMargined_dart>();
    uiWindowSetMargined = _lib
        .lookup<NativeFunction<uiWindowSetMargined_native>>(
            'uiWindowSetMargined')
        .asFunction<uiWindowSetMargined_dart>();
    uiWindowResizeable = _lib
        .lookup<NativeFunction<uiWindowResizeable_native>>(
            'uiWindowResizeable')
        .asFunction<uiWindowResizeable_dart>();
    uiWindowSetResizeable = _lib
        .lookup<NativeFunction<uiWindowSetResizeable_native>>(
            'uiWindowSetResizeable')
        .asFunction<uiWindowSetResizeable_dart>();
    uiNewWindow = _lib
        .lookup<NativeFunction<uiNewWindow_native>>('uiNewWindow')
        .asFunction<uiNewWindow_dart>();
    uiButtonText = _lib
        .lookup<NativeFunction<uiButtonText_native>>('uiButtonText')
        .asFunction<uiButtonText_dart>();
    uiButtonSetText = _lib
        .lookup<NativeFunction<uiButtonSetText_native>>('uiButtonSetText')
        .asFunction<uiButtonSetText_dart>();
    uiButtonOnClicked = _lib
        .lookup<NativeFunction<uiButtonOnClicked_native>>('uiButtonOnClicked')
        .asFunction<uiButtonOnClicked_dart>();
    uiNewButton = _lib
        .lookup<NativeFunction<uiNewButton_native>>('uiNewButton')
        .asFunction<uiNewButton_dart>();
    uiBoxAppend = _lib
        .lookup<NativeFunction<uiBoxAppend_native>>('uiBoxAppend')
        .asFunction<uiBoxAppend_dart>();
    uiBoxNumChildren = _lib
        .lookup<NativeFunction<uiBoxNumChildren_native>>('uiBoxNumChildren')
        .asFunction<uiBoxNumChildren_dart>();
    uiBoxDelete = _lib
        .lookup<NativeFunction<uiBoxDelete_native>>('uiBoxDelete')
        .asFunction<uiBoxDelete_dart>();
    uiBoxPadded = _lib
        .lookup<NativeFunction<uiBoxPadded_native>>('uiBoxPadded')
        .asFunction<uiBoxPadded_dart>();
    uiBoxSetPadded = _lib
        .lookup<NativeFunction<uiBoxSetPadded_native>>('uiBoxSetPadded')
        .asFunction<uiBoxSetPadded_dart>();
    uiNewHorizontalBox = _lib
        .lookup<NativeFunction<uiNewHorizontalBox_native>>(
            'uiNewHorizontalBox')
        .asFunction<uiNewHorizontalBox_dart>();
    uiNewVerticalBox = _lib
        .lookup<NativeFunction<uiNewVerticalBox_native>>('uiNewVerticalBox')
        .asFunction<uiNewVerticalBox_dart>();
    uiCheckboxText = _lib
        .lookup<NativeFunction<uiCheckboxText_native>>('uiCheckboxText')
        .asFunction<uiCheckboxText_dart>();
    uiCheckboxSetText = _lib
        .lookup<NativeFunction<uiCheckboxSetText_native>>('uiCheckboxSetText')
        .asFunction<uiCheckboxSetText_dart>();
    uiCheckboxOnToggled = _lib
        .lookup<NativeFunction<uiCheckboxOnToggled_native>>(
            'uiCheckboxOnToggled')
        .asFunction<uiCheckboxOnToggled_dart>();
    uiCheckboxChecked = _lib
        .lookup<NativeFunction<uiCheckboxChecked_native>>('uiCheckboxChecked')
        .asFunction<uiCheckboxChecked_dart>();
    uiCheckboxSetChecked = _lib
        .lookup<NativeFunction<uiCheckboxSetChecked_native>>(
            'uiCheckboxSetChecked')
        .asFunction<uiCheckboxSetChecked_dart>();
    uiNewCheckbox = _lib
        .lookup<NativeFunction<uiNewCheckbox_native>>('uiNewCheckbox')
        .asFunction<uiNewCheckbox_dart>();
    uiEntryText = _lib
        .lookup<NativeFunction<uiEntryText_native>>('uiEntryText')
        .asFunction<uiEntryText_dart>();
    uiEntrySetText = _lib
        .lookup<NativeFunction<uiEntrySetText_native>>('uiEntrySetText')
        .asFunction<uiEntrySetText_dart>();
    uiEntryOnChanged = _lib
        .lookup<NativeFunction<uiEntryOnChanged_native>>('uiEntryOnChanged')
        .asFunction<uiEntryOnChanged_dart>();
    uiEntryReadOnly = _lib
        .lookup<NativeFunction<uiEntryReadOnly_native>>('uiEntryReadOnly')
        .asFunction<uiEntryReadOnly_dart>();
    uiEntrySetReadOnly = _lib
        .lookup<NativeFunction<uiEntrySetReadOnly_native>>(
            'uiEntrySetReadOnly')
        .asFunction<uiEntrySetReadOnly_dart>();
    uiNewEntry = _lib
        .lookup<NativeFunction<uiNewEntry_native>>('uiNewEntry')
        .asFunction<uiNewEntry_dart>();
    uiNewPasswordEntry = _lib
        .lookup<NativeFunction<uiNewPasswordEntry_native>>(
            'uiNewPasswordEntry')
        .asFunction<uiNewPasswordEntry_dart>();
    uiNewSearchEntry = _lib
        .lookup<NativeFunction<uiNewSearchEntry_native>>('uiNewSearchEntry')
        .asFunction<uiNewSearchEntry_dart>();
    uiLabelText = _lib
        .lookup<NativeFunction<uiLabelText_native>>('uiLabelText')
        .asFunction<uiLabelText_dart>();
    uiLabelSetText = _lib
        .lookup<NativeFunction<uiLabelSetText_native>>('uiLabelSetText')
        .asFunction<uiLabelSetText_dart>();
    uiNewLabel = _lib
        .lookup<NativeFunction<uiNewLabel_native>>('uiNewLabel')
        .asFunction<uiNewLabel_dart>();
    uiTabAppend = _lib
        .lookup<NativeFunction<uiTabAppend_native>>('uiTabAppend')
        .asFunction<uiTabAppend_dart>();
    uiTabInsertAt = _lib
        .lookup<NativeFunction<uiTabInsertAt_native>>('uiTabInsertAt')
        .asFunction<uiTabInsertAt_dart>();
    uiTabDelete = _lib
        .lookup<NativeFunction<uiTabDelete_native>>('uiTabDelete')
        .asFunction<uiTabDelete_dart>();
    uiTabNumPages = _lib
        .lookup<NativeFunction<uiTabNumPages_native>>('uiTabNumPages')
        .asFunction<uiTabNumPages_dart>();
    uiTabMargined = _lib
        .lookup<NativeFunction<uiTabMargined_native>>('uiTabMargined')
        .asFunction<uiTabMargined_dart>();
    uiTabSetMargined = _lib
        .lookup<NativeFunction<uiTabSetMargined_native>>('uiTabSetMargined')
        .asFunction<uiTabSetMargined_dart>();
    uiNewTab =
        _lib.lookup<NativeFunction<uiNewTab_native>>('uiNewTab').asFunction<uiNewTab_dart>();
    uiGroupTitle = _lib
        .lookup<NativeFunction<uiGroupTitle_native>>('uiGroupTitle')
        .asFunction<uiGroupTitle_dart>();
    uiGroupSetTitle = _lib
        .lookup<NativeFunction<uiGroupSetTitle_native>>('uiGroupSetTitle')
        .asFunction<uiGroupSetTitle_dart>();
    uiGroupSetChild = _lib
        .lookup<NativeFunction<uiGroupSetChild_native>>('uiGroupSetChild')
        .asFunction<uiGroupSetChild_dart>();
    uiGroupMargined = _lib
        .lookup<NativeFunction<uiGroupMargined_native>>('uiGroupMargined')
        .asFunction<uiGroupMargined_dart>();
    uiGroupSetMargined = _lib
        .lookup<NativeFunction<uiGroupSetMargined_native>>(
            'uiGroupSetMargined')
        .asFunction<uiGroupSetMargined_dart>();
    uiNewGroup = _lib
        .lookup<NativeFunction<uiNewGroup_native>>('uiNewGroup')
        .asFunction<uiNewGroup_dart>();
    uiSpinboxValue = _lib
        .lookup<NativeFunction<uiSpinboxValue_native>>('uiSpinboxValue')
        .asFunction<uiSpinboxValue_dart>();
    uiSpinboxSetValue = _lib
        .lookup<NativeFunction<uiSpinboxSetValue_native>>('uiSpinboxSetValue')
        .asFunction<uiSpinboxSetValue_dart>();
    uiSpinboxOnChanged = _lib
        .lookup<NativeFunction<uiSpinboxOnChanged_native>>(
            'uiSpinboxOnChanged')
        .asFunction<uiSpinboxOnChanged_dart>();
    uiNewSpinbox = _lib
        .lookup<NativeFunction<uiNewSpinbox_native>>('uiNewSpinbox')
        .asFunction<uiNewSpinbox_dart>();
    uiSliderValue = _lib
        .lookup<NativeFunction<uiSliderValue_native>>('uiSliderValue')
        .asFunction<uiSliderValue_dart>();
    uiSliderSetValue = _lib
        .lookup<NativeFunction<uiSliderSetValue_native>>('uiSliderSetValue')
        .asFunction<uiSliderSetValue_dart>();
    uiSliderHasToolTip = _lib
        .lookup<NativeFunction<uiSliderHasToolTip_native>>(
            'uiSliderHasToolTip')
        .asFunction<uiSliderHasToolTip_dart>();
    uiSliderSetHasToolTip = _lib
        .lookup<NativeFunction<uiSliderSetHasToolTip_native>>(
            'uiSliderSetHasToolTip')
        .asFunction<uiSliderSetHasToolTip_dart>();
    uiSliderOnChanged = _lib
        .lookup<NativeFunction<uiSliderOnChanged_native>>('uiSliderOnChanged')
        .asFunction<uiSliderOnChanged_dart>();
    uiSliderOnReleased = _lib
        .lookup<NativeFunction<uiSliderOnReleased_native>>(
            'uiSliderOnReleased')
        .asFunction<uiSliderOnReleased_dart>();
    uiSliderSetRange = _lib
        .lookup<NativeFunction<uiSliderSetRange_native>>('uiSliderSetRange')
        .asFunction<uiSliderSetRange_dart>();
    uiNewSlider = _lib
        .lookup<NativeFunction<uiNewSlider_native>>('uiNewSlider')
        .asFunction<uiNewSlider_dart>();
    uiProgressBarValue = _lib
        .lookup<NativeFunction<uiProgressBarValue_native>>(
            'uiProgressBarValue')
        .asFunction<uiProgressBarValue_dart>();
    uiProgressBarSetValue = _lib
        .lookup<NativeFunction<uiProgressBarSetValue_native>>(
            'uiProgressBarSetValue')
        .asFunction<uiProgressBarSetValue_dart>();
    uiNewProgressBar = _lib
        .lookup<NativeFunction<uiNewProgressBar_native>>('uiNewProgressBar')
        .asFunction<uiNewProgressBar_dart>();
    uiNewHorizontalSeparator = _lib
        .lookup<NativeFunction<uiNewHorizontalSeparator_native>>(
            'uiNewHorizontalSeparator')
        .asFunction<uiNewHorizontalSeparator_dart>();
    uiNewVerticalSeparator = _lib
        .lookup<NativeFunction<uiNewVerticalSeparator_native>>(
            'uiNewVerticalSeparator')
        .asFunction<uiNewVerticalSeparator_dart>();
    uiComboboxAppend = _lib
        .lookup<NativeFunction<uiComboboxAppend_native>>('uiComboboxAppend')
        .asFunction<uiComboboxAppend_dart>();
    uiComboboxInsertAt = _lib
        .lookup<NativeFunction<uiComboboxInsertAt_native>>(
            'uiComboboxInsertAt')
        .asFunction<uiComboboxInsertAt_dart>();
    uiComboboxDelete = _lib
        .lookup<NativeFunction<uiComboboxDelete_native>>('uiComboboxDelete')
        .asFunction<uiComboboxDelete_dart>();
    uiComboboxClear = _lib
        .lookup<NativeFunction<uiComboboxClear_native>>('uiComboboxClear')
        .asFunction<uiComboboxClear_dart>();
    uiComboboxNumItems = _lib
        .lookup<NativeFunction<uiComboboxNumItems_native>>(
            'uiComboboxNumItems')
        .asFunction<uiComboboxNumItems_dart>();
    uiComboboxSelected = _lib
        .lookup<NativeFunction<uiComboboxSelected_native>>(
            'uiComboboxSelected')
        .asFunction<uiComboboxSelected_dart>();
    uiComboboxSetSelected = _lib
        .lookup<NativeFunction<uiComboboxSetSelected_native>>(
            'uiComboboxSetSelected')
        .asFunction<uiComboboxSetSelected_dart>();
    uiComboboxOnSelected = _lib
        .lookup<NativeFunction<uiComboboxOnSelected_native>>(
            'uiComboboxOnSelected')
        .asFunction<uiComboboxOnSelected_dart>();
    uiNewCombobox = _lib
        .lookup<NativeFunction<uiNewCombobox_native>>('uiNewCombobox')
        .asFunction<uiNewCombobox_dart>();
    uiEditableComboboxAppend = _lib
        .lookup<NativeFunction<uiEditableComboboxAppend_native>>(
            'uiEditableComboboxAppend')
        .asFunction<uiEditableComboboxAppend_dart>();
    uiEditableComboboxText = _lib
        .lookup<NativeFunction<uiEditableComboboxText_native>>(
            'uiEditableComboboxText')
        .asFunction<uiEditableComboboxText_dart>();
    uiEditableComboboxSetText = _lib
        .lookup<NativeFunction<uiEditableComboboxSetText_native>>(
            'uiEditableComboboxSetText')
        .asFunction<uiEditableComboboxSetText_dart>();
    uiEditableComboboxOnChanged = _lib
        .lookup<NativeFunction<uiEditableComboboxOnChanged_native>>(
            'uiEditableComboboxOnChanged')
        .asFunction<uiEditableComboboxOnChanged_dart>();
    uiNewEditableCombobox = _lib
        .lookup<NativeFunction<uiNewEditableCombobox_native>>(
            'uiNewEditableCombobox')
        .asFunction<uiNewEditableCombobox_dart>();
    uiRadioButtonsAppend = _lib
        .lookup<NativeFunction<uiRadioButtonsAppend_native>>(
            'uiRadioButtonsAppend')
        .asFunction<uiRadioButtonsAppend_dart>();
    uiRadioButtonsSelected = _lib
        .lookup<NativeFunction<uiRadioButtonsSelected_native>>(
            'uiRadioButtonsSelected')
        .asFunction<uiRadioButtonsSelected_dart>();
    uiRadioButtonsSetSelected = _lib
        .lookup<NativeFunction<uiRadioButtonsSetSelected_native>>(
            'uiRadioButtonsSetSelected')
        .asFunction<uiRadioButtonsSetSelected_dart>();
    uiRadioButtonsOnSelected = _lib
        .lookup<NativeFunction<uiRadioButtonsOnSelected_native>>(
            'uiRadioButtonsOnSelected')
        .asFunction<uiRadioButtonsOnSelected_dart>();
    uiNewRadioButtons = _lib
        .lookup<NativeFunction<uiNewRadioButtons_native>>(
            'uiNewRadioButtons')
        .asFunction<uiNewRadioButtons_dart>();
    uiDateTimePickerTime = _lib
        .lookup<NativeFunction<uiDateTimePickerTime_native>>(
            'uiDateTimePickerTime')
        .asFunction<uiDateTimePickerTime_dart>();
    uiDateTimePickerSetTime = _lib
        .lookup<NativeFunction<uiDateTimePickerSetTime_native>>(
            'uiDateTimePickerSetTime')
        .asFunction<uiDateTimePickerSetTime_dart>();
    uiDateTimePickerOnChanged = _lib
        .lookup<NativeFunction<uiDateTimePickerOnChanged_native>>(
            'uiDateTimePickerOnChanged')
        .asFunction<uiDateTimePickerOnChanged_dart>();
    uiNewDateTimePicker = _lib
        .lookup<NativeFunction<uiNewDateTimePicker_native>>(
            'uiNewDateTimePicker')
        .asFunction<uiNewDateTimePicker_dart>();
    uiNewDatePicker = _lib
        .lookup<NativeFunction<uiNewDatePicker_native>>('uiNewDatePicker')
        .asFunction<uiNewDatePicker_dart>();
    uiNewTimePicker = _lib
        .lookup<NativeFunction<uiNewTimePicker_native>>('uiNewTimePicker')
        .asFunction<uiNewTimePicker_dart>();
    uiMultilineEntryText = _lib
        .lookup<NativeFunction<uiMultilineEntryText_native>>(
            'uiMultilineEntryText')
        .asFunction<uiMultilineEntryText_dart>();
    uiMultilineEntrySetText = _lib
        .lookup<NativeFunction<uiMultilineEntrySetText_native>>(
            'uiMultilineEntrySetText')
        .asFunction<uiMultilineEntrySetText_dart>();
    uiMultilineEntryAppend = _lib
        .lookup<NativeFunction<uiMultilineEntryAppend_native>>(
            'uiMultilineEntryAppend')
        .asFunction<uiMultilineEntryAppend_dart>();
    uiMultilineEntryOnChanged = _lib
        .lookup<NativeFunction<uiMultilineEntryOnChanged_native>>(
            'uiMultilineEntryOnChanged')
        .asFunction<uiMultilineEntryOnChanged_dart>();
    uiMultilineEntryReadOnly = _lib
        .lookup<NativeFunction<uiMultilineEntryReadOnly_native>>(
            'uiMultilineEntryReadOnly')
        .asFunction<uiMultilineEntryReadOnly_dart>();
    uiMultilineEntrySetReadOnly = _lib
        .lookup<NativeFunction<uiMultilineEntrySetReadOnly_native>>(
            'uiMultilineEntrySetReadOnly')
        .asFunction<uiMultilineEntrySetReadOnly_dart>();
    uiNewMultilineEntry = _lib
        .lookup<NativeFunction<uiNewMultilineEntry_native>>(
            'uiNewMultilineEntry')
        .asFunction<uiNewMultilineEntry_dart>();
    uiNewNonWrappingMultilineEntry = _lib
        .lookup<NativeFunction<uiNewNonWrappingMultilineEntry_native>>(
            'uiNewNonWrappingMultilineEntry')
        .asFunction<uiNewNonWrappingMultilineEntry_dart>();
    uiMenuItemEnable = _lib
        .lookup<NativeFunction<uiMenuItemEnable_native>>('uiMenuItemEnable')
        .asFunction<uiMenuItemEnable_dart>();
    uiMenuItemDisable = _lib
        .lookup<NativeFunction<uiMenuItemDisable_native>>(
            'uiMenuItemDisable')
        .asFunction<uiMenuItemDisable_dart>();
    uiMenuItemOnClicked = _lib
        .lookup<NativeFunction<uiMenuItemOnClicked_native>>(
            'uiMenuItemOnClicked')
        .asFunction<uiMenuItemOnClicked_dart>();
    uiMenuItemChecked = _lib
        .lookup<NativeFunction<uiMenuItemChecked_native>>(
            'uiMenuItemChecked')
        .asFunction<uiMenuItemChecked_dart>();
    uiMenuItemSetChecked = _lib
        .lookup<NativeFunction<uiMenuItemSetChecked_native>>(
            'uiMenuItemSetChecked')
        .asFunction<uiMenuItemSetChecked_dart>();
    uiMenuAppendItem = _lib
        .lookup<NativeFunction<uiMenuAppendItem_native>>('uiMenuAppendItem')
        .asFunction<uiMenuAppendItem_dart>();
    uiMenuAppendCheckItem = _lib
        .lookup<NativeFunction<uiMenuAppendCheckItem_native>>(
            'uiMenuAppendCheckItem')
        .asFunction<uiMenuAppendCheckItem_dart>();
    uiMenuAppendQuitItem = _lib
        .lookup<NativeFunction<uiMenuAppendQuitItem_native>>(
            'uiMenuAppendQuitItem')
        .asFunction<uiMenuAppendQuitItem_dart>();
    uiMenuAppendPreferencesItem = _lib
        .lookup<NativeFunction<uiMenuAppendPreferencesItem_native>>(
            'uiMenuAppendPreferencesItem')
        .asFunction<uiMenuAppendPreferencesItem_dart>();
    uiMenuAppendAboutItem = _lib
        .lookup<NativeFunction<uiMenuAppendAboutItem_native>>(
            'uiMenuAppendAboutItem')
        .asFunction<uiMenuAppendAboutItem_dart>();
    uiMenuAppendSeparator = _lib
        .lookup<NativeFunction<uiMenuAppendSeparator_native>>(
            'uiMenuAppendSeparator')
        .asFunction<uiMenuAppendSeparator_dart>();
    uiNewMenu = _lib
        .lookup<NativeFunction<uiNewMenu_native>>('uiNewMenu')
        .asFunction<uiNewMenu_dart>();
    uiOpenFile = _lib
        .lookup<NativeFunction<uiOpenFile_native>>('uiOpenFile')
        .asFunction<uiOpenFile_dart>();
    uiOpenFolder = _lib
        .lookup<NativeFunction<uiOpenFolder_native>>('uiOpenFolder')
        .asFunction<uiOpenFolder_dart>();
    uiSaveFile = _lib
        .lookup<NativeFunction<uiSaveFile_native>>('uiSaveFile')
        .asFunction<uiSaveFile_dart>();
    uiMsgBox =
        _lib.lookup<NativeFunction<uiMsgBox_native>>('uiMsgBox').asFunction<uiMsgBox_dart>();
    uiMsgBoxError = _lib
        .lookup<NativeFunction<uiMsgBoxError_native>>('uiMsgBoxError')
        .asFunction<uiMsgBoxError_dart>();
    uiAreaSetSize = _lib
        .lookup<NativeFunction<uiAreaSetSize_native>>('uiAreaSetSize')
        .asFunction<uiAreaSetSize_dart>();
    uiAreaQueueRedrawAll = _lib
        .lookup<NativeFunction<uiAreaQueueRedrawAll_native>>(
            'uiAreaQueueRedrawAll')
        .asFunction<uiAreaQueueRedrawAll_dart>();
    uiAreaScrollTo = _lib
        .lookup<NativeFunction<uiAreaScrollTo_native>>('uiAreaScrollTo')
        .asFunction<uiAreaScrollTo_dart>();
    uiAreaBeginUserWindowMove = _lib
        .lookup<NativeFunction<uiAreaBeginUserWindowMove_native>>(
            'uiAreaBeginUserWindowMove')
        .asFunction<uiAreaBeginUserWindowMove_dart>();
    uiAreaBeginUserWindowResize = _lib
        .lookup<NativeFunction<uiAreaBeginUserWindowResize_native>>(
            'uiAreaBeginUserWindowResize')
        .asFunction<uiAreaBeginUserWindowResize_dart>();
    uiNewArea =
        _lib.lookup<NativeFunction<uiNewArea_native>>('uiNewArea').asFunction<uiNewArea_dart>();
    uiNewScrollingArea = _lib
        .lookup<NativeFunction<uiNewScrollingArea_native>>(
            'uiNewScrollingArea')
        .asFunction<uiNewScrollingArea_dart>();
    uiDrawNewPath = _lib
        .lookup<NativeFunction<uiDrawNewPath_native>>('uiDrawNewPath')
        .asFunction<uiDrawNewPath_dart>();
    uiDrawFreePath = _lib
        .lookup<NativeFunction<uiDrawFreePath_native>>('uiDrawFreePath')
        .asFunction<uiDrawFreePath_dart>();
    uiDrawPathNewFigure = _lib
        .lookup<NativeFunction<uiDrawPathNewFigure_native>>(
            'uiDrawPathNewFigure')
        .asFunction<uiDrawPathNewFigure_dart>();
    uiDrawPathNewFigureWithArc = _lib
        .lookup<NativeFunction<uiDrawPathNewFigureWithArc_native>>(
            'uiDrawPathNewFigureWithArc')
        .asFunction<uiDrawPathNewFigureWithArc_dart>();
    uiDrawPathLineTo = _lib
        .lookup<NativeFunction<uiDrawPathLineTo_native>>('uiDrawPathLineTo')
        .asFunction<uiDrawPathLineTo_dart>();
    uiDrawPathArcTo = _lib
        .lookup<NativeFunction<uiDrawPathArcTo_native>>('uiDrawPathArcTo')
        .asFunction<uiDrawPathArcTo_dart>();
    uiDrawPathBezierTo = _lib
        .lookup<NativeFunction<uiDrawPathBezierTo_native>>(
            'uiDrawPathBezierTo')
        .asFunction<uiDrawPathBezierTo_dart>();
    uiDrawPathCloseFigure = _lib
        .lookup<NativeFunction<uiDrawPathCloseFigure_native>>(
            'uiDrawPathCloseFigure')
        .asFunction<uiDrawPathCloseFigure_dart>();
    uiDrawPathAddRectangle = _lib
        .lookup<NativeFunction<uiDrawPathAddRectangle_native>>(
            'uiDrawPathAddRectangle')
        .asFunction<uiDrawPathAddRectangle_dart>();
    uiDrawPathEnded = _lib
        .lookup<NativeFunction<uiDrawPathEnded_native>>('uiDrawPathEnded')
        .asFunction<uiDrawPathEnded_dart>();
    uiDrawPathEnd = _lib
        .lookup<NativeFunction<uiDrawPathEnd_native>>('uiDrawPathEnd')
        .asFunction<uiDrawPathEnd_dart>();
    uiDrawStroke = _lib
        .lookup<NativeFunction<uiDrawStroke_native>>('uiDrawStroke')
        .asFunction<uiDrawStroke_dart>();
    uiDrawFill = _lib
        .lookup<NativeFunction<uiDrawFill_native>>('uiDrawFill')
        .asFunction<uiDrawFill_dart>();
    uiDrawMatrixSetIdentity = _lib
        .lookup<NativeFunction<uiDrawMatrixSetIdentity_native>>(
            'uiDrawMatrixSetIdentity')
        .asFunction<uiDrawMatrixSetIdentity_dart>();
    uiDrawMatrixTranslate = _lib
        .lookup<NativeFunction<uiDrawMatrixTranslate_native>>(
            'uiDrawMatrixTranslate')
        .asFunction<uiDrawMatrixTranslate_dart>();
    uiDrawMatrixScale = _lib
        .lookup<NativeFunction<uiDrawMatrixScale_native>>(
            'uiDrawMatrixScale')
        .asFunction<uiDrawMatrixScale_dart>();
    uiDrawMatrixRotate = _lib
        .lookup<NativeFunction<uiDrawMatrixRotate_native>>(
            'uiDrawMatrixRotate')
        .asFunction<uiDrawMatrixRotate_dart>();
    uiDrawMatrixSkew = _lib
        .lookup<NativeFunction<uiDrawMatrixSkew_native>>('uiDrawMatrixSkew')
        .asFunction<uiDrawMatrixSkew_dart>();
    uiDrawMatrixMultiply = _lib
        .lookup<NativeFunction<uiDrawMatrixMultiply_native>>(
            'uiDrawMatrixMultiply')
        .asFunction<uiDrawMatrixMultiply_dart>();
    uiDrawMatrixInvertible = _lib
        .lookup<NativeFunction<uiDrawMatrixInvertible_native>>(
            'uiDrawMatrixInvertible')
        .asFunction<uiDrawMatrixInvertible_dart>();
    uiDrawMatrixInvert = _lib
        .lookup<NativeFunction<uiDrawMatrixInvert_native>>(
            'uiDrawMatrixInvert')
        .asFunction<uiDrawMatrixInvert_dart>();
    uiDrawMatrixTransformPoint = _lib
        .lookup<NativeFunction<uiDrawMatrixTransformPoint_native>>(
            'uiDrawMatrixTransformPoint')
        .asFunction<uiDrawMatrixTransformPoint_dart>();
    uiDrawMatrixTransformSize = _lib
        .lookup<NativeFunction<uiDrawMatrixTransformSize_native>>(
            'uiDrawMatrixTransformSize')
        .asFunction<uiDrawMatrixTransformSize_dart>();
    uiDrawTransform = _lib
        .lookup<NativeFunction<uiDrawTransform_native>>('uiDrawTransform')
        .asFunction<uiDrawTransform_dart>();
    uiDrawClip = _lib
        .lookup<NativeFunction<uiDrawClip_native>>('uiDrawClip')
        .asFunction<uiDrawClip_dart>();
    uiDrawSave = _lib
        .lookup<NativeFunction<uiDrawSave_native>>('uiDrawSave')
        .asFunction<uiDrawSave_dart>();
    uiDrawRestore = _lib
        .lookup<NativeFunction<uiDrawRestore_native>>('uiDrawRestore')
        .asFunction<uiDrawRestore_dart>();
    uiFreeAttribute = _lib
        .lookup<NativeFunction<uiFreeAttribute_native>>('uiFreeAttribute')
        .asFunction<uiFreeAttribute_dart>();
    uiAttributeGetType = _lib
        .lookup<NativeFunction<uiAttributeGetType_native>>(
            'uiAttributeGetType')
        .asFunction<uiAttributeGetType_dart>();
    uiNewFamilyAttribute = _lib
        .lookup<NativeFunction<uiNewFamilyAttribute_native>>(
            'uiNewFamilyAttribute')
        .asFunction<uiNewFamilyAttribute_dart>();
    uiAttributeFamily = _lib
        .lookup<NativeFunction<uiAttributeFamily_native>>(
            'uiAttributeFamily')
        .asFunction<uiAttributeFamily_dart>();
    uiNewSizeAttribute = _lib
        .lookup<NativeFunction<uiNewSizeAttribute_native>>(
            'uiNewSizeAttribute')
        .asFunction<uiNewSizeAttribute_dart>();
    uiAttributeSize = _lib
        .lookup<NativeFunction<uiAttributeSize_native>>('uiAttributeSize')
        .asFunction<uiAttributeSize_dart>();
    uiNewWeightAttribute = _lib
        .lookup<NativeFunction<uiNewWeightAttribute_native>>(
            'uiNewWeightAttribute')
        .asFunction<uiNewWeightAttribute_dart>();
    uiAttributeWeight = _lib
        .lookup<NativeFunction<uiAttributeWeight_native>>(
            'uiAttributeWeight')
        .asFunction<uiAttributeWeight_dart>();
    uiNewItalicAttribute = _lib
        .lookup<NativeFunction<uiNewItalicAttribute_native>>(
            'uiNewItalicAttribute')
        .asFunction<uiNewItalicAttribute_dart>();
    uiAttributeItalic = _lib
        .lookup<NativeFunction<uiAttributeItalic_native>>(
            'uiAttributeItalic')
        .asFunction<uiAttributeItalic_dart>();
    uiNewStretchAttribute = _lib
        .lookup<NativeFunction<uiNewStretchAttribute_native>>(
            'uiNewStretchAttribute')
        .asFunction<uiNewStretchAttribute_dart>();
    uiAttributeStretch = _lib
        .lookup<NativeFunction<uiAttributeStretch_native>>(
            'uiAttributeStretch')
        .asFunction<uiAttributeStretch_dart>();
    uiNewColorAttribute = _lib
        .lookup<NativeFunction<uiNewColorAttribute_native>>(
            'uiNewColorAttribute')
        .asFunction<uiNewColorAttribute_dart>();
    uiAttributeColor = _lib
        .lookup<NativeFunction<uiAttributeColor_native>>('uiAttributeColor')
        .asFunction<uiAttributeColor_dart>();
    uiNewBackgroundAttribute = _lib
        .lookup<NativeFunction<uiNewBackgroundAttribute_native>>(
            'uiNewBackgroundAttribute')
        .asFunction<uiNewBackgroundAttribute_dart>();
    uiNewUnderlineAttribute = _lib
        .lookup<NativeFunction<uiNewUnderlineAttribute_native>>(
            'uiNewUnderlineAttribute')
        .asFunction<uiNewUnderlineAttribute_dart>();
    uiAttributeUnderline = _lib
        .lookup<NativeFunction<uiAttributeUnderline_native>>(
            'uiAttributeUnderline')
        .asFunction<uiAttributeUnderline_dart>();
    uiNewUnderlineColorAttribute = _lib
        .lookup<NativeFunction<uiNewUnderlineColorAttribute_native>>(
            'uiNewUnderlineColorAttribute')
        .asFunction<uiNewUnderlineColorAttribute_dart>();
    uiAttributeUnderlineColor = _lib
        .lookup<NativeFunction<uiAttributeUnderlineColor_native>>(
            'uiAttributeUnderlineColor')
        .asFunction<uiAttributeUnderlineColor_dart>();
    uiNewOpenTypeFeatures = _lib
        .lookup<NativeFunction<uiNewOpenTypeFeatures_native>>(
            'uiNewOpenTypeFeatures')
        .asFunction<uiNewOpenTypeFeatures_dart>();
    uiFreeOpenTypeFeatures = _lib
        .lookup<NativeFunction<uiFreeOpenTypeFeatures_native>>(
            'uiFreeOpenTypeFeatures')
        .asFunction<uiFreeOpenTypeFeatures_dart>();
    uiOpenTypeFeaturesClone = _lib
        .lookup<NativeFunction<uiOpenTypeFeaturesClone_native>>(
            'uiOpenTypeFeaturesClone')
        .asFunction<uiOpenTypeFeaturesClone_dart>();
    uiOpenTypeFeaturesAdd = _lib
        .lookup<NativeFunction<uiOpenTypeFeaturesAdd_native>>(
            'uiOpenTypeFeaturesAdd')
        .asFunction<uiOpenTypeFeaturesAdd_dart>();
    uiOpenTypeFeaturesRemove = _lib
        .lookup<NativeFunction<uiOpenTypeFeaturesRemove_native>>(
            'uiOpenTypeFeaturesRemove')
        .asFunction<uiOpenTypeFeaturesRemove_dart>();
    uiOpenTypeFeaturesGet = _lib
        .lookup<NativeFunction<uiOpenTypeFeaturesGet_native>>(
            'uiOpenTypeFeaturesGet')
        .asFunction<uiOpenTypeFeaturesGet_dart>();
    uiOpenTypeFeaturesForEach = _lib
        .lookup<NativeFunction<uiOpenTypeFeaturesForEach_native>>(
            'uiOpenTypeFeaturesForEach')
        .asFunction<uiOpenTypeFeaturesForEach_dart>();
    uiNewFeaturesAttribute = _lib
        .lookup<NativeFunction<uiNewFeaturesAttribute_native>>(
            'uiNewFeaturesAttribute')
        .asFunction<uiNewFeaturesAttribute_dart>();
    uiAttributeFeatures = _lib
        .lookup<NativeFunction<uiAttributeFeatures_native>>(
            'uiAttributeFeatures')
        .asFunction<uiAttributeFeatures_dart>();
    uiNewAttributedString = _lib
        .lookup<NativeFunction<uiNewAttributedString_native>>(
            'uiNewAttributedString')
        .asFunction<uiNewAttributedString_dart>();
    uiFreeAttributedString = _lib
        .lookup<NativeFunction<uiFreeAttributedString_native>>(
            'uiFreeAttributedString')
        .asFunction<uiFreeAttributedString_dart>();
    uiAttributedStringString = _lib
        .lookup<NativeFunction<uiAttributedStringString_native>>(
            'uiAttributedStringString')
        .asFunction<uiAttributedStringString_dart>();
    uiAttributedStringLen = _lib
        .lookup<NativeFunction<uiAttributedStringLen_native>>(
            'uiAttributedStringLen')
        .asFunction<uiAttributedStringLen_dart>();
    uiAttributedStringAppendUnattributed = _lib
        .lookup<NativeFunction<uiAttributedStringAppendUnattributed_native>>(
            'uiAttributedStringAppendUnattributed')
        .asFunction<uiAttributedStringAppendUnattributed_dart>();
    uiAttributedStringInsertAtUnattributed = _lib
        .lookup<NativeFunction<uiAttributedStringInsertAtUnattributed_native>>(
            'uiAttributedStringInsertAtUnattributed')
        .asFunction<uiAttributedStringInsertAtUnattributed_dart>();
    uiAttributedStringDelete = _lib
        .lookup<NativeFunction<uiAttributedStringDelete_native>>(
            'uiAttributedStringDelete')
        .asFunction<uiAttributedStringDelete_dart>();
    uiAttributedStringSetAttribute = _lib
        .lookup<NativeFunction<uiAttributedStringSetAttribute_native>>(
            'uiAttributedStringSetAttribute')
        .asFunction<uiAttributedStringSetAttribute_dart>();
    uiAttributedStringForEachAttribute = _lib
        .lookup<NativeFunction<uiAttributedStringForEachAttribute_native>>(
            'uiAttributedStringForEachAttribute')
        .asFunction<uiAttributedStringForEachAttribute_dart>();
    uiAttributedStringNumGraphemes = _lib
        .lookup<NativeFunction<uiAttributedStringNumGraphemes_native>>(
            'uiAttributedStringNumGraphemes')
        .asFunction<uiAttributedStringNumGraphemes_dart>();
    uiAttributedStringByteIndexToGrapheme = _lib
        .lookup<NativeFunction<uiAttributedStringByteIndexToGrapheme_native>>(
            'uiAttributedStringByteIndexToGrapheme')
        .asFunction<uiAttributedStringByteIndexToGrapheme_dart>();
    uiAttributedStringGraphemeToByteIndex = _lib
        .lookup<NativeFunction<uiAttributedStringGraphemeToByteIndex_native>>(
            'uiAttributedStringGraphemeToByteIndex')
        .asFunction<uiAttributedStringGraphemeToByteIndex_dart>();
    uiLoadControlFont = _lib
        .lookup<NativeFunction<uiLoadControlFont_native>>(
            'uiLoadControlFont')
        .asFunction<uiLoadControlFont_dart>();
    uiFreeFontDescriptor = _lib
        .lookup<NativeFunction<uiFreeFontDescriptor_native>>(
            'uiFreeFontDescriptor')
        .asFunction<uiFreeFontDescriptor_dart>();
    uiDrawNewTextLayout = _lib
        .lookup<NativeFunction<uiDrawNewTextLayout_native>>(
            'uiDrawNewTextLayout')
        .asFunction<uiDrawNewTextLayout_dart>();
    uiDrawFreeTextLayout = _lib
        .lookup<NativeFunction<uiDrawFreeTextLayout_native>>(
            'uiDrawFreeTextLayout')
        .asFunction<uiDrawFreeTextLayout_dart>();
    uiDrawText = _lib
        .lookup<NativeFunction<uiDrawText_native>>('uiDrawText')
        .asFunction<uiDrawText_dart>();
    uiDrawTextLayoutExtents = _lib
        .lookup<NativeFunction<uiDrawTextLayoutExtents_native>>(
            'uiDrawTextLayoutExtents')
        .asFunction<uiDrawTextLayoutExtents_dart>();
    uiFontButtonFont = _lib
        .lookup<NativeFunction<uiFontButtonFont_native>>('uiFontButtonFont')
        .asFunction<uiFontButtonFont_dart>();
    uiFontButtonOnChanged = _lib
        .lookup<NativeFunction<uiFontButtonOnChanged_native>>(
            'uiFontButtonOnChanged')
        .asFunction<uiFontButtonOnChanged_dart>();
    uiNewFontButton = _lib
        .lookup<NativeFunction<uiNewFontButton_native>>('uiNewFontButton')
        .asFunction<uiNewFontButton_dart>();
    uiFreeFontButtonFont = _lib
        .lookup<NativeFunction<uiFreeFontButtonFont_native>>(
            'uiFreeFontButtonFont')
        .asFunction<uiFreeFontButtonFont_dart>();
    uiColorButtonColor = _lib
        .lookup<NativeFunction<uiColorButtonColor_native>>(
            'uiColorButtonColor')
        .asFunction<uiColorButtonColor_dart>();
    uiColorButtonSetColor = _lib
        .lookup<NativeFunction<uiColorButtonSetColor_native>>(
            'uiColorButtonSetColor')
        .asFunction<uiColorButtonSetColor_dart>();
    uiColorButtonOnChanged = _lib
        .lookup<NativeFunction<uiColorButtonOnChanged_native>>(
            'uiColorButtonOnChanged')
        .asFunction<uiColorButtonOnChanged_dart>();
    uiNewColorButton = _lib
        .lookup<NativeFunction<uiNewColorButton_native>>('uiNewColorButton')
        .asFunction<uiNewColorButton_dart>();
    uiFormAppend = _lib
        .lookup<NativeFunction<uiFormAppend_native>>('uiFormAppend')
        .asFunction<uiFormAppend_dart>();
    uiFormNumChildren = _lib
        .lookup<NativeFunction<uiFormNumChildren_native>>('uiFormNumChildren')
        .asFunction<uiFormNumChildren_dart>();
    uiFormDelete = _lib
        .lookup<NativeFunction<uiFormDelete_native>>('uiFormDelete')
        .asFunction<uiFormDelete_dart>();
    uiFormPadded = _lib
        .lookup<NativeFunction<uiFormPadded_native>>('uiFormPadded')
        .asFunction<uiFormPadded_dart>();
    uiFormSetPadded = _lib
        .lookup<NativeFunction<uiFormSetPadded_native>>('uiFormSetPadded')
        .asFunction<uiFormSetPadded_dart>();
    uiNewForm =
        _lib.lookup<NativeFunction<uiNewForm_native>>('uiNewForm').asFunction<uiNewForm_dart>();
    uiGridAppend = _lib
        .lookup<NativeFunction<uiGridAppend_native>>('uiGridAppend')
        .asFunction<uiGridAppend_dart>();
    uiGridInsertAt = _lib
        .lookup<NativeFunction<uiGridInsertAt_native>>('uiGridInsertAt')
        .asFunction<uiGridInsertAt_dart>();
    uiGridPadded = _lib
        .lookup<NativeFunction<uiGridPadded_native>>('uiGridPadded')
        .asFunction<uiGridPadded_dart>();
    uiGridSetPadded = _lib
        .lookup<NativeFunction<uiGridSetPadded_native>>('uiGridSetPadded')
        .asFunction<uiGridSetPadded_dart>();
    uiNewGrid =
        _lib.lookup<NativeFunction<uiNewGrid_native>>('uiNewGrid').asFunction<uiNewGrid_dart>();
    uiNewImage = _lib
        .lookup<NativeFunction<uiNewImage_native>>('uiNewImage')
        .asFunction<uiNewImage_dart>();
    uiFreeImage = _lib
        .lookup<NativeFunction<uiFreeImage_native>>('uiFreeImage')
        .asFunction<uiFreeImage_dart>();
    uiImageAppend = _lib
        .lookup<NativeFunction<uiImageAppend_native>>('uiImageAppend')
        .asFunction<uiImageAppend_dart>();
    uiFreeTableValue = _lib
        .lookup<NativeFunction<uiFreeTableValue_native>>('uiFreeTableValue')
        .asFunction<uiFreeTableValue_dart>();
    uiTableValueGetType = _lib
        .lookup<NativeFunction<uiTableValueGetType_native>>(
            'uiTableValueGetType')
        .asFunction<uiTableValueGetType_dart>();
    uiNewTableValueString = _lib
        .lookup<NativeFunction<uiNewTableValueString_native>>(
            'uiNewTableValueString')
        .asFunction<uiNewTableValueString_dart>();
    uiTableValueString = _lib
        .lookup<NativeFunction<uiTableValueString_native>>(
            'uiTableValueString')
        .asFunction<uiTableValueString_dart>();
    uiNewTableValueImage = _lib
        .lookup<NativeFunction<uiNewTableValueImage_native>>(
            'uiNewTableValueImage')
        .asFunction<uiNewTableValueImage_dart>();
    uiTableValueImage = _lib
        .lookup<NativeFunction<uiTableValueImage_native>>(
            'uiTableValueImage')
        .asFunction<uiTableValueImage_dart>();
    uiNewTableValueInt = _lib
        .lookup<NativeFunction<uiNewTableValueInt_native>>(
            'uiNewTableValueInt')
        .asFunction<uiNewTableValueInt_dart>();
    uiTableValueInt = _lib
        .lookup<NativeFunction<uiTableValueInt_native>>('uiTableValueInt')
        .asFunction<uiTableValueInt_dart>();
    uiNewTableValueColor = _lib
        .lookup<NativeFunction<uiNewTableValueColor_native>>(
            'uiNewTableValueColor')
        .asFunction<uiNewTableValueColor_dart>();
    uiTableValueColor = _lib
        .lookup<NativeFunction<uiTableValueColor_native>>(
            'uiTableValueColor')
        .asFunction<uiTableValueColor_dart>();
    uiNewTableModel = _lib
        .lookup<NativeFunction<uiNewTableModel_native>>('uiNewTableModel')
        .asFunction<uiNewTableModel_dart>();
    uiFreeTableModel = _lib
        .lookup<NativeFunction<uiFreeTableModel_native>>('uiFreeTableModel')
        .asFunction<uiFreeTableModel_dart>();
    uiTableModelRowInserted = _lib
        .lookup<NativeFunction<uiTableModelRowInserted_native>>(
            'uiTableModelRowInserted')
        .asFunction<uiTableModelRowInserted_dart>();
    uiTableModelRowChanged = _lib
        .lookup<NativeFunction<uiTableModelRowChanged_native>>(
            'uiTableModelRowChanged')
        .asFunction<uiTableModelRowChanged_dart>();
    uiTableModelRowDeleted = _lib
        .lookup<NativeFunction<uiTableModelRowDeleted_native>>(
            'uiTableModelRowDeleted')
        .asFunction<uiTableModelRowDeleted_dart>();
    uiTableAppendTextColumn = _lib
        .lookup<NativeFunction<uiTableAppendTextColumn_native>>(
            'uiTableAppendTextColumn')
        .asFunction<uiTableAppendTextColumn_dart>();
    uiTableAppendImageColumn = _lib
        .lookup<NativeFunction<uiTableAppendImageColumn_native>>(
            'uiTableAppendImageColumn')
        .asFunction<uiTableAppendImageColumn_dart>();
    uiTableAppendImageTextColumn = _lib
        .lookup<NativeFunction<uiTableAppendImageTextColumn_native>>(
            'uiTableAppendImageTextColumn')
        .asFunction<uiTableAppendImageTextColumn_dart>();
    uiTableAppendCheckboxColumn = _lib
        .lookup<NativeFunction<uiTableAppendCheckboxColumn_native>>(
            'uiTableAppendCheckboxColumn')
        .asFunction<uiTableAppendCheckboxColumn_dart>();
    uiTableAppendCheckboxTextColumn = _lib
        .lookup<NativeFunction<uiTableAppendCheckboxTextColumn_native>>(
            'uiTableAppendCheckboxTextColumn')
        .asFunction<uiTableAppendCheckboxTextColumn_dart>();
    uiTableAppendProgressBarColumn = _lib
        .lookup<NativeFunction<uiTableAppendProgressBarColumn_native>>(
            'uiTableAppendProgressBarColumn')
        .asFunction<uiTableAppendProgressBarColumn_dart>();
    uiTableAppendButtonColumn = _lib
        .lookup<NativeFunction<uiTableAppendButtonColumn_native>>(
            'uiTableAppendButtonColumn')
        .asFunction<uiTableAppendButtonColumn_dart>();
    uiTableHeaderVisible = _lib
        .lookup<NativeFunction<uiTableHeaderVisible_native>>(
            'uiTableHeaderVisible')
        .asFunction<uiTableHeaderVisible_dart>();
    uiTableHeaderSetVisible = _lib
        .lookup<NativeFunction<uiTableHeaderSetVisible_native>>(
            'uiTableHeaderSetVisible')
        .asFunction<uiTableHeaderSetVisible_dart>();
    uiNewTable = _lib
        .lookup<NativeFunction<uiNewTable_native>>('uiNewTable')
        .asFunction<uiNewTable_dart>();
    uiTableOnRowClicked = _lib
        .lookup<NativeFunction<uiTableOnRowClicked_native>>(
            'uiTableOnRowClicked')
        .asFunction<uiTableOnRowClicked_dart>();
    uiTableOnRowDoubleClicked = _lib
        .lookup<NativeFunction<uiTableOnRowDoubleClicked_native>>(
            'uiTableOnRowDoubleClicked')
        .asFunction<uiTableOnRowDoubleClicked_dart>();
    uiTableHeaderSetSortIndicator = _lib
        .lookup<NativeFunction<uiTableHeaderSetSortIndicator_native>>(
            'uiTableHeaderSetSortIndicator')
        .asFunction<uiTableHeaderSetSortIndicator_dart>();
    uiTableHeaderSortIndicator = _lib
        .lookup<NativeFunction<uiTableHeaderSortIndicator_native>>(
            'uiTableHeaderSortIndicator')
        .asFunction<uiTableHeaderSortIndicator_dart>();
    uiTableHeaderOnClicked = _lib
        .lookup<NativeFunction<uiTableHeaderOnClicked_native>>(
            'uiTableHeaderOnClicked')
        .asFunction<uiTableHeaderOnClicked_dart>();
    uiTableColumnWidth = _lib
        .lookup<NativeFunction<uiTableColumnWidth_native>>(
            'uiTableColumnWidth')
        .asFunction<uiTableColumnWidth_dart>();
    uiTableColumnSetWidth = _lib
        .lookup<NativeFunction<uiTableColumnSetWidth_native>>(
            'uiTableColumnSetWidth')
        .asFunction<uiTableColumnSetWidth_dart>();
    uiTableGetSelectionMode = _lib
        .lookup<NativeFunction<uiTableGetSelectionMode_native>>(
            'uiTableGetSelectionMode')
        .asFunction<uiTableGetSelectionMode_dart>();
    uiTableSetSelectionMode = _lib
        .lookup<NativeFunction<uiTableSetSelectionMode_native>>(
            'uiTableSetSelectionMode')
        .asFunction<uiTableSetSelectionMode_dart>();
    uiTableOnSelectionChanged = _lib
        .lookup<NativeFunction<uiTableOnSelectionChanged_native>>(
            'uiTableOnSelectionChanged')
        .asFunction<uiTableOnSelectionChanged_dart>();
    uiTableGetSelection = _lib
        .lookup<NativeFunction<uiTableGetSelection_native>>(
            'uiTableGetSelection')
        .asFunction<uiTableGetSelection_dart>();
    uiTableSetSelection = _lib
        .lookup<NativeFunction<uiTableSetSelection_native>>(
            'uiTableSetSelection')
        .asFunction<uiTableSetSelection_dart>();
    uiFreeTableSelection = _lib
        .lookup<NativeFunction<uiFreeTableSelection_native>>(
            'uiFreeTableSelection')
        .asFunction<uiFreeTableSelection_dart>();
  }
}

// =============================================================================
// --- PONTEIROS OPACOS (HANDLES) ---
// =============================================================================

typedef uiControl = Pointer<Void>;
typedef uiWindow = Pointer<Void>;
typedef uiButton = Pointer<Void>;
typedef uiBox = Pointer<Void>;
typedef uiCheckbox = Pointer<Void>;
typedef uiEntry = Pointer<Void>;
typedef uiLabel = Pointer<Void>;
typedef uiTab = Pointer<Void>;
typedef uiGroup = Pointer<Void>;
typedef uiSpinbox = Pointer<Void>;
typedef uiSlider = Pointer<Void>;
typedef uiProgressBar = Pointer<Void>;
typedef uiSeparator = Pointer<Void>;
typedef uiCombobox = Pointer<Void>;
typedef uiEditableCombobox = Pointer<Void>;
typedef uiRadioButtons = Pointer<Void>;
typedef uiDateTimePicker = Pointer<Void>;
typedef uiMultilineEntry = Pointer<Void>;
typedef uiMenuItem = Pointer<Void>;
typedef uiMenu = Pointer<Void>;
typedef uiArea = Pointer<Void>;
typedef uiAreaHandler = Pointer<uiAreaHandlerStruct>;
typedef uiDrawContext = Pointer<Void>;
typedef uiDrawPath = Pointer<Void>;
typedef uiDrawMatrix = Pointer<uiDrawMatrixStruct>;
typedef uiDrawBrush = Pointer<uiDrawBrushStruct>;
typedef uiDrawStrokeParams = Pointer<uiDrawStrokeParamsStruct>;
typedef uiAttribute = Pointer<Void>;
typedef uiOpenTypeFeatures = Pointer<Void>;
typedef uiAttributedString = Pointer<Void>;
typedef uiFontDescriptor = Pointer<uiFontDescriptorStruct>;
typedef uiDrawTextLayout = Pointer<Void>;
typedef uiFontButton = Pointer<Void>;
typedef uiColorButton = Pointer<Void>;
typedef uiForm = Pointer<Void>;
typedef uiGrid = Pointer<Void>;
typedef uiImage = Pointer<Void>;
typedef uiTableValue = Pointer<Void>;
typedef uiTableModel = Pointer<Void>;
typedef uiTableModelHandler = Pointer<uiTableModelHandlerStruct>;
typedef uiTable = Pointer<Void>;
typedef uiTableSelection = Pointer<uiTableSelectionStruct>;

// =============================================================================
// --- ESTRUTURAS (C STRUCTS) ---
// =============================================================================

final class uiInitOptions extends Struct {
  @IntPtr()
  external int Size;
}

final class tm extends Struct {
  @Int32()
  external int tm_sec;
  @Int32()
  external int tm_min;
  @Int32()
  external int tm_hour;
  @Int32()
  external int tm_mday;
  @Int32()
  external int tm_mon;
  @Int32()
  external int tm_year;
  @Int32()
  external int tm_wday;
  @Int32()
  external int tm_yday;
  @Int32()
  external int tm_isdst;
  // Campos específicos do glibc (não-Windows)
  @IntPtr() // long
  external int tm_gmtoff;
  external Pointer<Utf8> tm_zone;
}

final class uiAreaHandlerStruct extends Struct {
  external Pointer<
      NativeFunction<
          Void Function(uiAreaHandler, uiArea,
              Pointer<uiAreaDrawParamsStruct>)>> Draw;
  external Pointer<
      NativeFunction<
          Void Function(
              uiAreaHandler, uiArea, Pointer<uiAreaMouseEventStruct>)>> MouseEvent;
  external Pointer<
      NativeFunction<
          Void Function(uiAreaHandler, uiArea, Int32)>> MouseCrossed;
  external Pointer<NativeFunction<Void Function(uiAreaHandler, uiArea)>>
      DragBroken;
  external Pointer<
      NativeFunction<
          Int32 Function(
              uiAreaHandler, uiArea, Pointer<uiAreaKeyEventStruct>)>> KeyEvent;
}

final class uiAreaDrawParamsStruct extends Struct {
  external uiDrawContext Context;
  @Double()
  external double AreaWidth;
  @Double()
  external double AreaHeight;
  @Double()
  external double ClipX;
  @Double()
  external double ClipY;
  @Double()
  external double ClipWidth;
  @Double()
  external double ClipHeight;
}

final class uiDrawMatrixStruct extends Struct {
  @Double()
  external double M11;
  @Double()
  external double M12;
  @Double()
  external double M21;
  @Double()
  external double M22;
  @Double()
  external double M31;
  @Double()
  external double M32;
}

final class uiDrawBrushGradientStopStruct extends Struct {
  @Double()
  external double Pos;
  @Double()
  external double R;
  @Double()
  external double G;
  @Double()
  external double B;
  @Double()
  external double A;
}

final class uiDrawBrushStruct extends Struct {
  @Int32()
  external int Type; // uiDrawBrushType
  @Double()
  external double R;
  @Double()
  external double G;
  @Double()
  external double B;
  @Double()
  external double A;
  @Double()
  external double X0;
  @Double()
  external double Y0;
  @Double()
  external double X1;
  @Double()
  external double Y1;
  @Double()
  external double OuterRadius;
  external Pointer<uiDrawBrushGradientStopStruct> Stops;
  @IntPtr() // size_t
  external int NumStops;
}

final class uiDrawStrokeParamsStruct extends Struct {
  @Int32()
  external int Cap; // uiDrawLineCap
  @Int32()
  external int Join; // uiDrawLineJoin
  @Double()
  external double Thickness;
  @Double()
  external double MiterLimit;
  external Pointer<Double> Dashes;
  @IntPtr() // size_t
  external int NumDashes;
  @Double()
  external double DashPhase;
}

final class uiFontDescriptorStruct extends Struct {
  external Pointer<Utf8> Family;
  @Double()
  external double Size;
  @Int32()
  external int Weight; // uiTextWeight
  @Int32()
  external int Italic; // uiTextItalic
  @Int32()
  external int Stretch; // uiTextStretch
}

final class uiDrawTextLayoutParamsStruct extends Struct {
  external uiAttributedString String;
  external uiFontDescriptor DefaultFont;
  @Double()
  external double Width;
  @Int32()
  external int Align; // uiDrawTextAlign
}

final class uiAreaMouseEventStruct extends Struct {
  @Double()
  external double X;
  @Double()
  external double Y;
  @Double()
  external double AreaWidth;
  @Double()
  external double AreaHeight;
  @Int32()
  external int Down;
  @Int32()
  external int Up;
  @Int32()
  external int Count;
  @Int32()
  external int Modifiers; // uiModifiers
  @Uint64()
  external int Held1To64;
}

final class uiAreaKeyEventStruct extends Struct {
  @Int8()
  external int Key; // char
  @Int32()
  external int ExtKey; // uiExtKey
  @Int32()
  external int Modifier; // uiModifiers
  @Int32()
  external int Modifiers; // uiModifiers
  @Int32()
  external int Up;
}

final class uiTableModelHandlerStruct extends Struct {
  external Pointer<
          NativeFunction<Int32 Function(uiTableModelHandler, uiTableModel)>>
      NumColumns;
  external Pointer<
      NativeFunction<
          Int32 Function(uiTableModelHandler, uiTableModel, Int32)>> ColumnType;
  external Pointer<
          NativeFunction<Int32 Function(uiTableModelHandler, uiTableModel)>>
      NumRows;
  external Pointer<
      NativeFunction<
          uiTableValue Function(
              uiTableModelHandler, uiTableModel, Int32, Int32)>> CellValue;
  external Pointer<
      NativeFunction<
          Void Function(uiTableModelHandler, uiTableModel, Int32, Int32,
              uiTableValue)>> SetCellValue;
}

final class uiTableTextColumnOptionalParamsStruct extends Struct {
  @Int32()
  external int ColorModelColumn;
}

final class uiTableParamsStruct extends Struct {
  external uiTableModel Model;
  @Int32()
  external int RowBackgroundColorModelColumn;
}

final class uiTableSelectionStruct extends Struct {
  @Int32()
  external int NumRows;
  external Pointer<Int32> Rows;
}

// =============================================================================
// --- CONSTANTES E ENUMS ---
// =============================================================================

// uiDrawBrushType
const int uiDrawBrushTypeSolid = 0;
const int uiDrawBrushTypeLinearGradient = 1;
const int uiDrawBrushTypeRadialGradient = 2;
const int uiDrawBrushTypeImage = 3;

// uiDrawLineCap
const int uiDrawLineCapFlat = 0;
const int uiDrawLineCapRound = 1;
const int uiDrawLineCapSquare = 2;

// uiDrawLineJoin
const int uiDrawLineJoinMiter = 0;
const int uiDrawLineJoinRound = 1;
const int uiDrawLineJoinBevel = 2;

// uiDrawFillMode
const int uiDrawFillModeWinding = 0;
const int uiDrawFillModeAlternate = 1;

// uiAlign
const int uiAlignFill = 0;
const int uiAlignStart = 1;
const int uiAlignCenter = 2;
const int uiAlignEnd = 3;

// uiAt
const int uiAtLeading = 0;
const int uiAtTop = 1;
const int uiAtTrailing = 2;
const int uiAtBottom = 3;

// uiWindowResizeEdge
const int uiWindowResizeEdgeLeft = 0;
const int uiWindowResizeEdgeTop = 1;
const int uiWindowResizeEdgeRight = 2;
const int uiWindowResizeEdgeBottom = 3;
const int uiWindowResizeEdgeTopLeft = 4;
const int uiWindowResizeEdgeTopRight = 5;
const int uiWindowResizeEdgeBottomLeft = 6;
const int uiWindowResizeEdgeBottomRight = 7;

// uiTableValueType
const int uiTableValueTypeString = 0;
const int uiTableValueTypeImage = 1;
const int uiTableValueTypeInt = 2;
const int uiTableValueTypeColor = 3;

// uiSortIndicator
const int uiSortIndicatorNone = 0;
const int uiSortIndicatorAscending = 1;
const int uiSortIndicatorDescending = 2;

// uiTableSelectionMode
const int uiTableSelectionModeNone = 0;
const int uiTableSelectionModeZeroOrOne = 1;
const int uiTableSelectionModeOne = 2;
const int uiTableSelectionModeZeroOrMany = 3;

// =============================================================================
// --- ASSINATURAS DE FUNÇÕES (TYPEDEFS) ---
// =============================================================================

// --- Core ---
typedef uiInit_native = Pointer<Utf8> Function(Pointer<uiInitOptions> options);
typedef uiInit_dart = Pointer<Utf8> Function(Pointer<uiInitOptions> options);

typedef uiUninit_native = Void Function();
typedef uiUninit_dart = void Function();

typedef uiFreeInitError_native = Void Function(Pointer<Utf8> err);
typedef uiFreeInitError_dart = void Function(Pointer<Utf8> err);

typedef uiMain_native = Void Function();
typedef uiMain_dart = void Function();

typedef uiMainSteps_native = Void Function();
typedef uiMainSteps_dart = void Function();

typedef uiMainStep_native = Int32 Function(Int32 wait);
typedef uiMainStep_dart = int Function(int wait);

typedef uiQuit_native = Void Function();
typedef uiQuit_dart = void Function();

typedef uiQueueMain_callback = Void Function(Pointer<Void> data);
typedef uiQueueMain_native = Void Function(
    Pointer<NativeFunction<uiQueueMain_callback>> f, Pointer<Void> data);
typedef uiQueueMain_dart = void Function(
    Pointer<NativeFunction<uiQueueMain_callback>> f, Pointer<Void> data);

typedef uiTimer_callback = Int32 Function(Pointer<Void> data);
typedef uiTimer_native = Void Function(Int32 milliseconds,
    Pointer<NativeFunction<uiTimer_callback>> f, Pointer<Void> data);
typedef uiTimer_dart = void Function(int milliseconds,
    Pointer<NativeFunction<uiTimer_callback>> f, Pointer<Void> data);

typedef uiOnShouldQuit_callback = Int32 Function(Pointer<Void> data);
typedef uiOnShouldQuit_native = Void Function(
    Pointer<NativeFunction<uiOnShouldQuit_callback>> f, Pointer<Void> data);
typedef uiOnShouldQuit_dart = void Function(
    Pointer<NativeFunction<uiOnShouldQuit_callback>> f, Pointer<Void> data);

typedef uiFreeText_native = Void Function(Pointer<Utf8> text);
typedef uiFreeText_dart = void Function(Pointer<Utf8> text);

// --- Control ---
typedef uiControlDestroy_native = Void Function(uiControl c);
typedef uiControlDestroy_dart = void Function(uiControl c);

typedef uiControlHandle_native = IntPtr Function(uiControl c);
typedef uiControlHandle_dart = int Function(uiControl c);

typedef uiControlParent_native = uiControl Function(uiControl c);
typedef uiControlParent_dart = uiControl Function(uiControl c);

typedef uiControlSetParent_native = Void Function(uiControl c, uiControl parent);
typedef uiControlSetParent_dart = void Function(uiControl c, uiControl parent);

typedef uiControlToplevel_native = Int32 Function(uiControl c);
typedef uiControlToplevel_dart = int Function(uiControl c);

typedef uiControlVisible_native = Int32 Function(uiControl c);
typedef uiControlVisible_dart = int Function(uiControl c);

typedef uiControlShow_native = Void Function(uiControl c);
typedef uiControlShow_dart = void Function(uiControl c);

typedef uiControlHide_native = Void Function(uiControl c);
typedef uiControlHide_dart = void Function(uiControl c);

typedef uiControlEnabled_native = Int32 Function(uiControl c);
typedef uiControlEnabled_dart = int Function(uiControl c);

typedef uiControlEnable_native = Void Function(uiControl c);
typedef uiControlEnable_dart = void Function(uiControl c);

typedef uiControlDisable_native = Void Function(uiControl c);
typedef uiControlDisable_dart = void Function(uiControl c);

typedef uiAllocControl_native = uiControl Function(
    IntPtr n, Uint32 OSsig, Uint32 typesig, Pointer<Utf8> typenamestr);
typedef uiAllocControl_dart = uiControl Function(
    int n, int OSsig, int typesig, Pointer<Utf8> typenamestr);

typedef uiFreeControl_native = Void Function(uiControl c);
typedef uiFreeControl_dart = void Function(uiControl c);

typedef uiControlVerifySetParent_native = Void Function(
    uiControl c, uiControl parent);
typedef uiControlVerifySetParent_dart = void Function(
    uiControl c, uiControl parent);

typedef uiControlEnabledToUser_native = Int32 Function(uiControl c);
typedef uiControlEnabledToUser_dart = int Function(uiControl c);

typedef uiUserBugCannotSetParentOnToplevel_native = Void Function(
    Pointer<Utf8> type);
typedef uiUserBugCannotSetParentOnToplevel_dart = void Function(
    Pointer<Utf8> type);

// --- Window ---
typedef uiWindowTitle_native = Pointer<Utf8> Function(uiWindow w);
typedef uiWindowTitle_dart = Pointer<Utf8> Function(uiWindow w);

typedef uiWindowSetTitle_native = Void Function(uiWindow w, Pointer<Utf8> title);
typedef uiWindowSetTitle_dart = void Function(uiWindow w, Pointer<Utf8> title);

typedef uiWindowPosition_native = Void Function(
    uiWindow w, Pointer<Int32> x, Pointer<Int32> y);
typedef uiWindowPosition_dart = void Function(
    uiWindow w, Pointer<Int32> x, Pointer<Int32> y);

typedef uiWindowSetPosition_native = Void Function(uiWindow w, Int32 x, Int32 y);
typedef uiWindowSetPosition_dart = void Function(uiWindow w, int x, int y);

typedef uiWindowOnPositionChanged_callback = Void Function(
    uiWindow sender, Pointer<Void> senderData);
typedef uiWindowOnPositionChanged_native = Void Function(
    uiWindow w,
    Pointer<NativeFunction<uiWindowOnPositionChanged_callback>> f,
    Pointer<Void> data);
typedef uiWindowOnPositionChanged_dart = void Function(
    uiWindow w,
    Pointer<NativeFunction<uiWindowOnPositionChanged_callback>> f,
    Pointer<Void> data);

typedef uiWindowContentSize_native = Void Function(
    uiWindow w, Pointer<Int32> width, Pointer<Int32> height);
typedef uiWindowContentSize_dart = void Function(
    uiWindow w, Pointer<Int32> width, Pointer<Int32> height);

typedef uiWindowSetContentSize_native = Void Function(
    uiWindow w, Int32 width, Int32 height);
typedef uiWindowSetContentSize_dart = void Function(
    uiWindow w, int width, int height);

typedef uiWindowFullscreen_native = Int32 Function(uiWindow w);
typedef uiWindowFullscreen_dart = int Function(uiWindow w);

typedef uiWindowSetFullscreen_native = Void Function(uiWindow w, Int32 fullscreen);
typedef uiWindowSetFullscreen_dart = void Function(uiWindow w, int fullscreen);

typedef uiWindowOnContentSizeChanged_callback = Void Function(
    uiWindow sender, Pointer<Void> senderData);
typedef uiWindowOnContentSizeChanged_native = Void Function(
    uiWindow w,
    Pointer<NativeFunction<uiWindowOnContentSizeChanged_callback>> f,
    Pointer<Void> data);
typedef uiWindowOnContentSizeChanged_dart = void Function(
    uiWindow w,
    Pointer<NativeFunction<uiWindowOnContentSizeChanged_callback>> f,
    Pointer<Void> data);

typedef uiWindowOnClosing_callback = Int32 Function(
    uiWindow sender, Pointer<Void> senderData);
typedef uiWindowOnClosing_native = Void Function(uiWindow w,
    Pointer<NativeFunction<uiWindowOnClosing_callback>> f, Pointer<Void> data);
typedef uiWindowOnClosing_dart = void Function(uiWindow w,
    Pointer<NativeFunction<uiWindowOnClosing_callback>> f, Pointer<Void> data);

typedef uiWindowOnFocusChanged_callback = Void Function(
    uiWindow sender, Pointer<Void> senderData);
typedef uiWindowOnFocusChanged_native = Void Function(
    uiWindow w,
    Pointer<NativeFunction<uiWindowOnFocusChanged_callback>> f,
    Pointer<Void> data);
typedef uiWindowOnFocusChanged_dart = void Function(
    uiWindow w,
    Pointer<NativeFunction<uiWindowOnFocusChanged_callback>> f,
    Pointer<Void> data);

typedef uiWindowFocused_native = Int32 Function(uiWindow w);
typedef uiWindowFocused_dart = int Function(uiWindow w);

typedef uiWindowBorderless_native = Int32 Function(uiWindow w);
typedef uiWindowBorderless_dart = int Function(uiWindow w);

typedef uiWindowSetBorderless_native = Void Function(
    uiWindow w, Int32 borderless);
typedef uiWindowSetBorderless_dart = void Function(uiWindow w, int borderless);

typedef uiWindowSetChild_native = Void Function(uiWindow w, uiControl child);
typedef uiWindowSetChild_dart = void Function(uiWindow w, uiControl child);

typedef uiWindowMargined_native = Int32 Function(uiWindow w);
typedef uiWindowMargined_dart = int Function(uiWindow w);

typedef uiWindowSetMargined_native = Void Function(uiWindow w, Int32 margined);
typedef uiWindowSetMargined_dart = void Function(uiWindow w, int margined);

typedef uiWindowResizeable_native = Int32 Function(uiWindow w);
typedef uiWindowResizeable_dart = int Function(uiWindow w);

typedef uiWindowSetResizeable_native = Void Function(
    uiWindow w, Int32 resizeable);
typedef uiWindowSetResizeable_dart = void Function(uiWindow w, int resizeable);

typedef uiNewWindow_native = uiWindow Function(
    Pointer<Utf8> title, Int32 width, Int32 height, Int32 hasMenubar);
typedef uiNewWindow_dart = uiWindow Function(
    Pointer<Utf8> title, int width, int height, int hasMenubar);

// --- Button ---
typedef uiButtonText_native = Pointer<Utf8> Function(uiButton b);
typedef uiButtonText_dart = Pointer<Utf8> Function(uiButton b);

typedef uiButtonSetText_native = Void Function(uiButton b, Pointer<Utf8> text);
typedef uiButtonSetText_dart = void Function(uiButton b, Pointer<Utf8> text);

typedef uiButtonOnClicked_callback = Void Function(
    uiButton sender, Pointer<Void> senderData);
typedef uiButtonOnClicked_native = Void Function(uiButton b,
    Pointer<NativeFunction<uiButtonOnClicked_callback>> f, Pointer<Void> data);
typedef uiButtonOnClicked_dart = void Function(uiButton b,
    Pointer<NativeFunction<uiButtonOnClicked_callback>> f, Pointer<Void> data);

typedef uiNewButton_native = uiButton Function(Pointer<Utf8> text);
typedef uiNewButton_dart = uiButton Function(Pointer<Utf8> text);

// --- Box ---
typedef uiBoxAppend_native = Void Function(
    uiBox b, uiControl child, Int32 stretchy);
typedef uiBoxAppend_dart = void Function(uiBox b, uiControl child, int stretchy);

typedef uiBoxNumChildren_native = Int32 Function(uiBox b);
typedef uiBoxNumChildren_dart = int Function(uiBox b);

typedef uiBoxDelete_native = Void Function(uiBox b, Int32 index);
typedef uiBoxDelete_dart = void Function(uiBox b, int index);

typedef uiBoxPadded_native = Int32 Function(uiBox b);
typedef uiBoxPadded_dart = int Function(uiBox b);

typedef uiBoxSetPadded_native = Void Function(uiBox b, Int32 padded);
typedef uiBoxSetPadded_dart = void Function(uiBox b, int padded);

typedef uiNewHorizontalBox_native = uiBox Function();
typedef uiNewHorizontalBox_dart = uiBox Function();

typedef uiNewVerticalBox_native = uiBox Function();
typedef uiNewVerticalBox_dart = uiBox Function();

// --- Checkbox ---
typedef uiCheckboxText_native = Pointer<Utf8> Function(uiCheckbox c);
typedef uiCheckboxText_dart = Pointer<Utf8> Function(uiCheckbox c);

typedef uiCheckboxSetText_native = Void Function(
    uiCheckbox c, Pointer<Utf8> text);
typedef uiCheckboxSetText_dart = void Function(
    uiCheckbox c, Pointer<Utf8> text);

typedef uiCheckboxOnToggled_callback = Void Function(
    uiCheckbox sender, Pointer<Void> senderData);
typedef uiCheckboxOnToggled_native = Void Function(
    uiCheckbox c,
    Pointer<NativeFunction<uiCheckboxOnToggled_callback>> f,
    Pointer<Void> data);
typedef uiCheckboxOnToggled_dart = void Function(
    uiCheckbox c,
    Pointer<NativeFunction<uiCheckboxOnToggled_callback>> f,
    Pointer<Void> data);

typedef uiCheckboxChecked_native = Int32 Function(uiCheckbox c);
typedef uiCheckboxChecked_dart = int Function(uiCheckbox c);

typedef uiCheckboxSetChecked_native = Void Function(uiCheckbox c, Int32 checked);
typedef uiCheckboxSetChecked_dart = void Function(uiCheckbox c, int checked);

typedef uiNewCheckbox_native = uiCheckbox Function(Pointer<Utf8> text);
typedef uiNewCheckbox_dart = uiCheckbox Function(Pointer<Utf8> text);

// --- Entry ---
typedef uiEntryText_native = Pointer<Utf8> Function(uiEntry e);
typedef uiEntryText_dart = Pointer<Utf8> Function(uiEntry e);

typedef uiEntrySetText_native = Void Function(uiEntry e, Pointer<Utf8> text);
typedef uiEntrySetText_dart = void Function(uiEntry e, Pointer<Utf8> text);

typedef uiEntryOnChanged_callback = Void Function(
    uiEntry sender, Pointer<Void> senderData);
typedef uiEntryOnChanged_native = Void Function(uiEntry e,
    Pointer<NativeFunction<uiEntryOnChanged_callback>> f, Pointer<Void> data);
typedef uiEntryOnChanged_dart = void Function(uiEntry e,
    Pointer<NativeFunction<uiEntryOnChanged_callback>> f, Pointer<Void> data);

typedef uiEntryReadOnly_native = Int32 Function(uiEntry e);
typedef uiEntryReadOnly_dart = int Function(uiEntry e);

typedef uiEntrySetReadOnly_native = Void Function(uiEntry e, Int32 readonly);
typedef uiEntrySetReadOnly_dart = void Function(uiEntry e, int readonly);

typedef uiNewEntry_native = uiEntry Function();
typedef uiNewEntry_dart = uiEntry Function();

typedef uiNewPasswordEntry_native = uiEntry Function();
typedef uiNewPasswordEntry_dart = uiEntry Function();

typedef uiNewSearchEntry_native = uiEntry Function();
typedef uiNewSearchEntry_dart = uiEntry Function();

// --- Label ---
typedef uiLabelText_native = Pointer<Utf8> Function(uiLabel l);
typedef uiLabelText_dart = Pointer<Utf8> Function(uiLabel l);

typedef uiLabelSetText_native = Void Function(uiLabel l, Pointer<Utf8> text);
typedef uiLabelSetText_dart = void Function(uiLabel l, Pointer<Utf8> text);

typedef uiNewLabel_native = uiLabel Function(Pointer<Utf8> text);
typedef uiNewLabel_dart = uiLabel Function(Pointer<Utf8> text);

// --- Tab ---
typedef uiTabAppend_native = Void Function(
    uiTab t, Pointer<Utf8> name, uiControl c);
typedef uiTabAppend_dart = void Function(
    uiTab t, Pointer<Utf8> name, uiControl c);

typedef uiTabInsertAt_native = Void Function(
    uiTab t, Pointer<Utf8> name, Int32 index, uiControl c);
typedef uiTabInsertAt_dart = void Function(
    uiTab t, Pointer<Utf8> name, int index, uiControl c);

typedef uiTabDelete_native = Void Function(uiTab t, Int32 index);
typedef uiTabDelete_dart = void Function(uiTab t, int index);

typedef uiTabNumPages_native = Int32 Function(uiTab t);
typedef uiTabNumPages_dart = int Function(uiTab t);

typedef uiTabMargined_native = Int32 Function(uiTab t, Int32 index);
typedef uiTabMargined_dart = int Function(uiTab t, int index);

typedef uiTabSetMargined_native = Void Function(
    uiTab t, Int32 index, Int32 margined);
typedef uiTabSetMargined_dart = void Function(
    uiTab t, int index, int margined);

typedef uiNewTab_native = uiTab Function();
typedef uiNewTab_dart = uiTab Function();

// --- Group ---
typedef uiGroupTitle_native = Pointer<Utf8> Function(uiGroup g);
typedef uiGroupTitle_dart = Pointer<Utf8> Function(uiGroup g);

typedef uiGroupSetTitle_native = Void Function(uiGroup g, Pointer<Utf8> title);
typedef uiGroupSetTitle_dart = void Function(uiGroup g, Pointer<Utf8> title);

typedef uiGroupSetChild_native = Void Function(uiGroup g, uiControl c);
typedef uiGroupSetChild_dart = void Function(uiGroup g, uiControl c);

typedef uiGroupMargined_native = Int32 Function(uiGroup g);
typedef uiGroupMargined_dart = int Function(uiGroup g);

typedef uiGroupSetMargined_native = Void Function(uiGroup g, Int32 margined);
typedef uiGroupSetMargined_dart = void Function(uiGroup g, int margined);

typedef uiNewGroup_native = uiGroup Function(Pointer<Utf8> title);
typedef uiNewGroup_dart = uiGroup Function(Pointer<Utf8> title);

// --- Spinbox ---
typedef uiSpinboxValue_native = Int32 Function(uiSpinbox s);
typedef uiSpinboxValue_dart = int Function(uiSpinbox s);

typedef uiSpinboxSetValue_native = Void Function(uiSpinbox s, Int32 value);
typedef uiSpinboxSetValue_dart = void Function(uiSpinbox s, int value);

typedef uiSpinboxOnChanged_callback = Void Function(
    uiSpinbox sender, Pointer<Void> senderData);
typedef uiSpinboxOnChanged_native = Void Function(
    uiSpinbox s,
    Pointer<NativeFunction<uiSpinboxOnChanged_callback>> f,
    Pointer<Void> data);
typedef uiSpinboxOnChanged_dart = void Function(
    uiSpinbox s,
    Pointer<NativeFunction<uiSpinboxOnChanged_callback>> f,
    Pointer<Void> data);

typedef uiNewSpinbox_native = uiSpinbox Function(Int32 min, Int32 max);
typedef uiNewSpinbox_dart = uiSpinbox Function(int min, int max);

// --- Slider ---
typedef uiSliderValue_native = Int32 Function(uiSlider s);
typedef uiSliderValue_dart = int Function(uiSlider s);

typedef uiSliderSetValue_native = Void Function(uiSlider s, Int32 value);
typedef uiSliderSetValue_dart = void Function(uiSlider s, int value);

typedef uiSliderHasToolTip_native = Int32 Function(uiSlider s);
typedef uiSliderHasToolTip_dart = int Function(uiSlider s);

typedef uiSliderSetHasToolTip_native = Void Function(uiSlider s, Int32 hasToolTip);
typedef uiSliderSetHasToolTip_dart = void Function(uiSlider s, int hasToolTip);

typedef uiSliderOnChanged_callback = Void Function(
    uiSlider sender, Pointer<Void> senderData);
typedef uiSliderOnChanged_native = Void Function(uiSlider s,
    Pointer<NativeFunction<uiSliderOnChanged_callback>> f, Pointer<Void> data);
typedef uiSliderOnChanged_dart = void Function(uiSlider s,
    Pointer<NativeFunction<uiSliderOnChanged_callback>> f, Pointer<Void> data);

typedef uiSliderOnReleased_callback = Void Function(
    uiSlider sender, Pointer<Void> senderData);
typedef uiSliderOnReleased_native = Void Function(
    uiSlider s,
    Pointer<NativeFunction<uiSliderOnReleased_callback>> f,
    Pointer<Void> data);
typedef uiSliderOnReleased_dart = void Function(
    uiSlider s,
    Pointer<NativeFunction<uiSliderOnReleased_callback>> f,
    Pointer<Void> data);

typedef uiSliderSetRange_native = Void Function(uiSlider s, Int32 min, Int32 max);
typedef uiSliderSetRange_dart = void Function(uiSlider s, int min, int max);

typedef uiNewSlider_native = uiSlider Function(Int32 min, Int32 max);
typedef uiNewSlider_dart = uiSlider Function(int min, int max);

// --- ProgressBar ---
typedef uiProgressBarValue_native = Int32 Function(uiProgressBar p);
typedef uiProgressBarValue_dart = int Function(uiProgressBar p);

typedef uiProgressBarSetValue_native = Void Function(uiProgressBar p, Int32 n);
typedef uiProgressBarSetValue_dart = void Function(uiProgressBar p, int n);

typedef uiNewProgressBar_native = uiProgressBar Function();
typedef uiNewProgressBar_dart = uiProgressBar Function();

// --- Separator ---
typedef uiNewHorizontalSeparator_native = uiSeparator Function();
typedef uiNewHorizontalSeparator_dart = uiSeparator Function();

typedef uiNewVerticalSeparator_native = uiSeparator Function();
typedef uiNewVerticalSeparator_dart = uiSeparator Function();

// --- Combobox ---
typedef uiComboboxAppend_native = Void Function(
    uiCombobox c, Pointer<Utf8> text);
typedef uiComboboxAppend_dart = void Function(
    uiCombobox c, Pointer<Utf8> text);

typedef uiComboboxInsertAt_native = Void Function(
    uiCombobox c, Int32 index, Pointer<Utf8> text);
typedef uiComboboxInsertAt_dart = void Function(
    uiCombobox c, int index, Pointer<Utf8> text);

typedef uiComboboxDelete_native = Void Function(uiCombobox c, Int32 index);
typedef uiComboboxDelete_dart = void Function(uiCombobox c, int index);

typedef uiComboboxClear_native = Void Function(uiCombobox c);
typedef uiComboboxClear_dart = void Function(uiCombobox c);

typedef uiComboboxNumItems_native = Int32 Function(uiCombobox c);
typedef uiComboboxNumItems_dart = int Function(uiCombobox c);

typedef uiComboboxSelected_native = Int32 Function(uiCombobox c);
typedef uiComboboxSelected_dart = int Function(uiCombobox c);

typedef uiComboboxSetSelected_native = Void Function(uiCombobox c, Int32 index);
typedef uiComboboxSetSelected_dart = void Function(uiCombobox c, int index);

typedef uiComboboxOnSelected_callback = Void Function(
    uiCombobox sender, Pointer<Void> senderData);
typedef uiComboboxOnSelected_native = Void Function(
    uiCombobox c,
    Pointer<NativeFunction<uiComboboxOnSelected_callback>> f,
    Pointer<Void> data);
typedef uiComboboxOnSelected_dart = void Function(
    uiCombobox c,
    Pointer<NativeFunction<uiComboboxOnSelected_callback>> f,
    Pointer<Void> data);

typedef uiNewCombobox_native = uiCombobox Function();
typedef uiNewCombobox_dart = uiCombobox Function();

// --- EditableCombobox ---
typedef uiEditableComboboxAppend_native = Void Function(
    uiEditableCombobox c, Pointer<Utf8> text);
typedef uiEditableComboboxAppend_dart = void Function(
    uiEditableCombobox c, Pointer<Utf8> text);

typedef uiEditableComboboxText_native = Pointer<Utf8> Function(
    uiEditableCombobox c);
typedef uiEditableComboboxText_dart = Pointer<Utf8> Function(
    uiEditableCombobox c);

typedef uiEditableComboboxSetText_native = Void Function(
    uiEditableCombobox c, Pointer<Utf8> text);
typedef uiEditableComboboxSetText_dart = void Function(
    uiEditableCombobox c, Pointer<Utf8> text);

typedef uiEditableComboboxOnChanged_callback = Void Function(
    uiEditableCombobox sender, Pointer<Void> senderData);
typedef uiEditableComboboxOnChanged_native = Void Function(
    uiEditableCombobox c,
    Pointer<NativeFunction<uiEditableComboboxOnChanged_callback>> f,
    Pointer<Void> data);
typedef uiEditableComboboxOnChanged_dart = void Function(
    uiEditableCombobox c,
    Pointer<NativeFunction<uiEditableComboboxOnChanged_callback>> f,
    Pointer<Void> data);

typedef uiNewEditableCombobox_native = uiEditableCombobox Function();
typedef uiNewEditableCombobox_dart = uiEditableCombobox Function();

// --- RadioButtons ---
typedef uiRadioButtonsAppend_native = Void Function(
    uiRadioButtons r, Pointer<Utf8> text);
typedef uiRadioButtonsAppend_dart = void Function(
    uiRadioButtons r, Pointer<Utf8> text);

typedef uiRadioButtonsSelected_native = Int32 Function(uiRadioButtons r);
typedef uiRadioButtonsSelected_dart = int Function(uiRadioButtons r);

typedef uiRadioButtonsSetSelected_native = Void Function(
    uiRadioButtons r, Int32 index);
typedef uiRadioButtonsSetSelected_dart = void Function(
    uiRadioButtons r, int index);

typedef uiRadioButtonsOnSelected_callback = Void Function(
    uiRadioButtons sender, Pointer<Void> senderData);
typedef uiRadioButtonsOnSelected_native = Void Function(
    uiRadioButtons r,
    Pointer<NativeFunction<uiRadioButtonsOnSelected_callback>> f,
    Pointer<Void> data);
typedef uiRadioButtonsOnSelected_dart = void Function(
    uiRadioButtons r,
    Pointer<NativeFunction<uiRadioButtonsOnSelected_callback>> f,
    Pointer<Void> data);

typedef uiNewRadioButtons_native = uiRadioButtons Function();
typedef uiNewRadioButtons_dart = uiRadioButtons Function();

// --- DateTimePicker ---
typedef uiDateTimePickerTime_native = Void Function(
    uiDateTimePicker d, Pointer<tm> time);
typedef uiDateTimePickerTime_dart = void Function(
    uiDateTimePicker d, Pointer<tm> time);

typedef uiDateTimePickerSetTime_native = Void Function(
    uiDateTimePicker d, Pointer<tm> time);
typedef uiDateTimePickerSetTime_dart = void Function(
    uiDateTimePicker d, Pointer<tm> time);

typedef uiDateTimePickerOnChanged_callback = Void Function(
    uiDateTimePicker sender, Pointer<Void> senderData);
typedef uiDateTimePickerOnChanged_native = Void Function(
    uiDateTimePicker d,
    Pointer<NativeFunction<uiDateTimePickerOnChanged_callback>> f,
    Pointer<Void> data);
typedef uiDateTimePickerOnChanged_dart = void Function(
    uiDateTimePicker d,
    Pointer<NativeFunction<uiDateTimePickerOnChanged_callback>> f,
    Pointer<Void> data);

typedef uiNewDateTimePicker_native = uiDateTimePicker Function();
typedef uiNewDateTimePicker_dart = uiDateTimePicker Function();

typedef uiNewDatePicker_native = uiDateTimePicker Function();
typedef uiNewDatePicker_dart = uiDateTimePicker Function();

typedef uiNewTimePicker_native = uiDateTimePicker Function();
typedef uiNewTimePicker_dart = uiDateTimePicker Function();

// --- MultilineEntry ---
typedef uiMultilineEntryText_native = Pointer<Utf8> Function(
    uiMultilineEntry e);
typedef uiMultilineEntryText_dart = Pointer<Utf8> Function(
    uiMultilineEntry e);

typedef uiMultilineEntrySetText_native = Void Function(
    uiMultilineEntry e, Pointer<Utf8> text);
typedef uiMultilineEntrySetText_dart = void Function(
    uiMultilineEntry e, Pointer<Utf8> text);

typedef uiMultilineEntryAppend_native = Void Function(
    uiMultilineEntry e, Pointer<Utf8> text);
typedef uiMultilineEntryAppend_dart = void Function(
    uiMultilineEntry e, Pointer<Utf8> text);

typedef uiMultilineEntryOnChanged_callback = Void Function(
    uiMultilineEntry sender, Pointer<Void> senderData);
typedef uiMultilineEntryOnChanged_native = Void Function(
    uiMultilineEntry e,
    Pointer<NativeFunction<uiMultilineEntryOnChanged_callback>> f,
    Pointer<Void> data);
typedef uiMultilineEntryOnChanged_dart = void Function(
    uiMultilineEntry e,
    Pointer<NativeFunction<uiMultilineEntryOnChanged_callback>> f,
    Pointer<Void> data);

typedef uiMultilineEntryReadOnly_native = Int32 Function(uiMultilineEntry e);
typedef uiMultilineEntryReadOnly_dart = int Function(uiMultilineEntry e);

typedef uiMultilineEntrySetReadOnly_native = Void Function(
    uiMultilineEntry e, Int32 readonly);
typedef uiMultilineEntrySetReadOnly_dart = void Function(
    uiMultilineEntry e, int readonly);

typedef uiNewMultilineEntry_native = uiMultilineEntry Function();
typedef uiNewMultilineEntry_dart = uiMultilineEntry Function();

typedef uiNewNonWrappingMultilineEntry_native = uiMultilineEntry Function();
typedef uiNewNonWrappingMultilineEntry_dart = uiMultilineEntry Function();

// --- MenuItem ---
typedef uiMenuItemEnable_native = Void Function(uiMenuItem m);
typedef uiMenuItemEnable_dart = void Function(uiMenuItem m);

typedef uiMenuItemDisable_native = Void Function(uiMenuItem m);
typedef uiMenuItemDisable_dart = void Function(uiMenuItem m);

typedef uiMenuItemOnClicked_callback = Void Function(
    uiMenuItem sender, uiWindow window, Pointer<Void> senderData);
typedef uiMenuItemOnClicked_native = Void Function(
    uiMenuItem m,
    Pointer<NativeFunction<uiMenuItemOnClicked_callback>> f,
    Pointer<Void> data);
typedef uiMenuItemOnClicked_dart = void Function(
    uiMenuItem m,
    Pointer<NativeFunction<uiMenuItemOnClicked_callback>> f,
    Pointer<Void> data);

typedef uiMenuItemChecked_native = Int32 Function(uiMenuItem m);
typedef uiMenuItemChecked_dart = int Function(uiMenuItem m);

typedef uiMenuItemSetChecked_native = Void Function(uiMenuItem m, Int32 checked);
typedef uiMenuItemSetChecked_dart = void Function(uiMenuItem m, int checked);

// --- Menu ---
typedef uiMenuAppendItem_native = uiMenuItem Function(
    uiMenu m, Pointer<Utf8> name);
typedef uiMenuAppendItem_dart = uiMenuItem Function(
    uiMenu m, Pointer<Utf8> name);

typedef uiMenuAppendCheckItem_native = uiMenuItem Function(
    uiMenu m, Pointer<Utf8> name);
typedef uiMenuAppendCheckItem_dart = uiMenuItem Function(
    uiMenu m, Pointer<Utf8> name);

typedef uiMenuAppendQuitItem_native = uiMenuItem Function(uiMenu m);
typedef uiMenuAppendQuitItem_dart = uiMenuItem Function(uiMenu m);

typedef uiMenuAppendPreferencesItem_native = uiMenuItem Function(uiMenu m);
typedef uiMenuAppendPreferencesItem_dart = uiMenuItem Function(uiMenu m);

typedef uiMenuAppendAboutItem_native = uiMenuItem Function(uiMenu m);
typedef uiMenuAppendAboutItem_dart = uiMenuItem Function(uiMenu m);

typedef uiMenuAppendSeparator_native = Void Function(uiMenu m);
typedef uiMenuAppendSeparator_dart = void Function(uiMenu m);

typedef uiNewMenu_native = uiMenu Function(Pointer<Utf8> name);
typedef uiNewMenu_dart = uiMenu Function(Pointer<Utf8> name);

// --- Dialogs ---
typedef uiOpenFile_native = Pointer<Utf8> Function(uiWindow parent);
typedef uiOpenFile_dart = Pointer<Utf8> Function(uiWindow parent);

typedef uiOpenFolder_native = Pointer<Utf8> Function(uiWindow parent);
typedef uiOpenFolder_dart = Pointer<Utf8> Function(uiWindow parent);

typedef uiSaveFile_native = Pointer<Utf8> Function(uiWindow parent);
typedef uiSaveFile_dart = Pointer<Utf8> Function(uiWindow parent);

typedef uiMsgBox_native = Void Function(
    uiWindow parent, Pointer<Utf8> title, Pointer<Utf8> description);
typedef uiMsgBox_dart = void Function(
    uiWindow parent, Pointer<Utf8> title, Pointer<Utf8> description);

typedef uiMsgBoxError_native = Void Function(
    uiWindow parent, Pointer<Utf8> title, Pointer<Utf8> description);
typedef uiMsgBoxError_dart = void Function(
    uiWindow parent, Pointer<Utf8> title, Pointer<Utf8> description);

// --- Area ---
typedef uiAreaSetSize_native = Void Function(uiArea a, Int32 width, Int32 height);
typedef uiAreaSetSize_dart = void Function(uiArea a, int width, int height);

typedef uiAreaQueueRedrawAll_native = Void Function(uiArea a);
typedef uiAreaQueueRedrawAll_dart = void Function(uiArea a);

typedef uiAreaScrollTo_native = Void Function(
    uiArea a, Double x, Double y, Double width, Double height);
typedef uiAreaScrollTo_dart = void Function(
    uiArea a, double x, double y, double width, double height);

typedef uiAreaBeginUserWindowMove_native = Void Function(uiArea a);
typedef uiAreaBeginUserWindowMove_dart = void Function(uiArea a);

typedef uiAreaBeginUserWindowResize_native = Void Function(
    uiArea a, Int32 edge);
typedef uiAreaBeginUserWindowResize_dart = void Function(
    uiArea a, int edge);

typedef uiNewArea_native = uiArea Function(uiAreaHandler ah);
typedef uiNewArea_dart = uiArea Function(uiAreaHandler ah);

typedef uiNewScrollingArea_native = uiArea Function(
    uiAreaHandler ah, Int32 width, Int32 height);
typedef uiNewScrollingArea_dart = uiArea Function(
    uiAreaHandler ah, int width, int height);

// --- Drawing (Paths) ---
typedef uiDrawNewPath_native = uiDrawPath Function(Int32 fillMode);
typedef uiDrawNewPath_dart = uiDrawPath Function(int fillMode);

typedef uiDrawFreePath_native = Void Function(uiDrawPath p);
typedef uiDrawFreePath_dart = void Function(uiDrawPath p);

typedef uiDrawPathNewFigure_native = Void Function(uiDrawPath p, Double x, Double y);
typedef uiDrawPathNewFigure_dart = void Function(uiDrawPath p, double x, double y);

typedef uiDrawPathNewFigureWithArc_native = Void Function(uiDrawPath p, Double xCenter,
    Double yCenter, Double radius, Double startAngle, Double sweep, Int32 negative);
typedef uiDrawPathNewFigureWithArc_dart = void Function(
    uiDrawPath p,
    double xCenter,
    double yCenter,
    double radius,
    double startAngle,
    double sweep,
    int negative);

typedef uiDrawPathLineTo_native = Void Function(uiDrawPath p, Double x, Double y);
typedef uiDrawPathLineTo_dart = void Function(uiDrawPath p, double x, double y);

typedef uiDrawPathArcTo_native = Void Function(uiDrawPath p, Double xCenter,
    Double yCenter, Double radius, Double startAngle, Double sweep, Int32 negative);
typedef uiDrawPathArcTo_dart = void Function(
    uiDrawPath p,
    double xCenter,
    double yCenter,
    double radius,
    double startAngle,
    double sweep,
    int negative);

typedef uiDrawPathBezierTo_native = Void Function(uiDrawPath p, Double c1x,
    Double c1y, Double c2x, Double c2y, Double endX, Double endY);
typedef uiDrawPathBezierTo_dart = void Function(uiDrawPath p, double c1x,
    double c1y, double c2x, double c2y, double endX, double endY);

typedef uiDrawPathCloseFigure_native = Void Function(uiDrawPath p);
typedef uiDrawPathCloseFigure_dart = void Function(uiDrawPath p);

typedef uiDrawPathAddRectangle_native = Void Function(
    uiDrawPath p, Double x, Double y, Double width, Double height);
typedef uiDrawPathAddRectangle_dart = void Function(
    uiDrawPath p, double x, double y, double width, double height);

typedef uiDrawPathEnded_native = Int32 Function(uiDrawPath p);
typedef uiDrawPathEnded_dart = int Function(uiDrawPath p);

typedef uiDrawPathEnd_native = Void Function(uiDrawPath p);
typedef uiDrawPathEnd_dart = void Function(uiDrawPath p);

typedef uiDrawStroke_native = Void Function(
    uiDrawContext c, uiDrawPath path, uiDrawBrush b, uiDrawStrokeParams p);
typedef uiDrawStroke_dart = void Function(
    uiDrawContext c, uiDrawPath path, uiDrawBrush b, uiDrawStrokeParams p);

typedef uiDrawFill_native = Void Function(
    uiDrawContext c, uiDrawPath path, uiDrawBrush b);
typedef uiDrawFill_dart = void Function(
    uiDrawContext c, uiDrawPath path, uiDrawBrush b);

// --- Drawing (Matrix) ---
typedef uiDrawMatrixSetIdentity_native = Void Function(uiDrawMatrix m);
typedef uiDrawMatrixSetIdentity_dart = void Function(uiDrawMatrix m);

typedef uiDrawMatrixTranslate_native = Void Function(
    uiDrawMatrix m, Double x, Double y);
typedef uiDrawMatrixTranslate_dart = void Function(
    uiDrawMatrix m, double x, double y);

typedef uiDrawMatrixScale_native = Void Function(
    uiDrawMatrix m, Double xCenter, Double yCenter, Double x, Double y);
typedef uiDrawMatrixScale_dart = void Function(
    uiDrawMatrix m, double xCenter, double yCenter, double x, double y);

typedef uiDrawMatrixRotate_native = Void Function(
    uiDrawMatrix m, Double x, Double y, Double amount);
typedef uiDrawMatrixRotate_dart = void Function(
    uiDrawMatrix m, double x, double y, double amount);

typedef uiDrawMatrixSkew_native = Void Function(
    uiDrawMatrix m, Double x, Double y, Double xamount, Double yamount);
typedef uiDrawMatrixSkew_dart = void Function(
    uiDrawMatrix m, double x, double y, double xamount, double yamount);

typedef uiDrawMatrixMultiply_native = Void Function(
    uiDrawMatrix dest, uiDrawMatrix src);
typedef uiDrawMatrixMultiply_dart = void Function(
    uiDrawMatrix dest, uiDrawMatrix src);

typedef uiDrawMatrixInvertible_native = Int32 Function(uiDrawMatrix m);
typedef uiDrawMatrixInvertible_dart = int Function(uiDrawMatrix m);

typedef uiDrawMatrixInvert_native = Int32 Function(uiDrawMatrix m);
typedef uiDrawMatrixInvert_dart = int Function(uiDrawMatrix m);

typedef uiDrawMatrixTransformPoint_native = Void Function(
    uiDrawMatrix m, Pointer<Double> x, Pointer<Double> y);
typedef uiDrawMatrixTransformPoint_dart = void Function(
    uiDrawMatrix m, Pointer<Double> x, Pointer<Double> y);

typedef uiDrawMatrixTransformSize_native = Void Function(
    uiDrawMatrix m, Pointer<Double> x, Pointer<Double> y);
typedef uiDrawMatrixTransformSize_dart = void Function(
    uiDrawMatrix m, Pointer<Double> x, Pointer<Double> y);

// --- Drawing (Context) ---
typedef uiDrawTransform_native = Void Function(uiDrawContext c, uiDrawMatrix m);
typedef uiDrawTransform_dart = void Function(uiDrawContext c, uiDrawMatrix m);

typedef uiDrawClip_native = Void Function(uiDrawContext c, uiDrawPath path);
typedef uiDrawClip_dart = void Function(uiDrawContext c, uiDrawPath path);

typedef uiDrawSave_native = Void Function(uiDrawContext c);
typedef uiDrawSave_dart = void Function(uiDrawContext c);

typedef uiDrawRestore_native = Void Function(uiDrawContext c);
typedef uiDrawRestore_dart = void Function(uiDrawContext c);

// --- Drawing (Attributes) ---
typedef uiFreeAttribute_native = Void Function(uiAttribute a);
typedef uiFreeAttribute_dart = void Function(uiAttribute a);

typedef uiAttributeGetType_native = Int32 Function(uiAttribute a);
typedef uiAttributeGetType_dart = int Function(uiAttribute a);

typedef uiNewFamilyAttribute_native = uiAttribute Function(
    Pointer<Utf8> family);
typedef uiNewFamilyAttribute_dart = uiAttribute Function(Pointer<Utf8> family);

typedef uiAttributeFamily_native = Pointer<Utf8> Function(uiAttribute a);
typedef uiAttributeFamily_dart = Pointer<Utf8> Function(uiAttribute a);

typedef uiNewSizeAttribute_native = uiAttribute Function(Double size);
typedef uiNewSizeAttribute_dart = uiAttribute Function(double size);

typedef uiAttributeSize_native = Double Function(uiAttribute a);
typedef uiAttributeSize_dart = double Function(uiAttribute a);

typedef uiNewWeightAttribute_native = uiAttribute Function(Int32 weight);
typedef uiNewWeightAttribute_dart = uiAttribute Function(int weight);

typedef uiAttributeWeight_native = Int32 Function(uiAttribute a);
typedef uiAttributeWeight_dart = int Function(uiAttribute a);

typedef uiNewItalicAttribute_native = uiAttribute Function(Int32 italic);
typedef uiNewItalicAttribute_dart = uiAttribute Function(int italic);

typedef uiAttributeItalic_native = Int32 Function(uiAttribute a);
typedef uiAttributeItalic_dart = int Function(uiAttribute a);

typedef uiNewStretchAttribute_native = uiAttribute Function(Int32 stretch);
typedef uiNewStretchAttribute_dart = uiAttribute Function(int stretch);

typedef uiAttributeStretch_native = Int32 Function(uiAttribute a);
typedef uiAttributeStretch_dart = int Function(uiAttribute a);

typedef uiNewColorAttribute_native = uiAttribute Function(
    Double r, Double g, Double b, Double a);
typedef uiNewColorAttribute_dart = uiAttribute Function(
    double r, double g, double b, double a);

typedef uiAttributeColor_native = Void Function(uiAttribute a, Pointer<Double> r,
    Pointer<Double> g, Pointer<Double> b, Pointer<Double> alpha);
typedef uiAttributeColor_dart = void Function(uiAttribute a, Pointer<Double> r,
    Pointer<Double> g, Pointer<Double> b, Pointer<Double> alpha);

typedef uiNewBackgroundAttribute_native = uiAttribute Function(
    Double r, Double g, Double b, Double a);
typedef uiNewBackgroundAttribute_dart = uiAttribute Function(
    double r, double g, double b, double a);

typedef uiNewUnderlineAttribute_native = uiAttribute Function(Int32 u);
typedef uiNewUnderlineAttribute_dart = uiAttribute Function(int u);

typedef uiAttributeUnderline_native = Int32 Function(uiAttribute a);
typedef uiAttributeUnderline_dart = int Function(uiAttribute a);

typedef uiNewUnderlineColorAttribute_native = uiAttribute Function(
    Int32 u, Double r, Double g, Double b, Double a);
typedef uiNewUnderlineColorAttribute_dart = uiAttribute Function(
    int u, double r, double g, double b, double a);

typedef uiAttributeUnderlineColor_native = Void Function(
    uiAttribute a,
    Pointer<Int32> u,
    Pointer<Double> r,
    Pointer<Double> g,
    Pointer<Double> b,
    Pointer<Double> alpha);
typedef uiAttributeUnderlineColor_dart = void Function(
    uiAttribute a,
    Pointer<Int32> u,
    Pointer<Double> r,
    Pointer<Double> g,
    Pointer<Double> b,
    Pointer<Double> alpha);

// --- OpenType Features ---
typedef uiOpenTypeFeaturesForEachFunc_callback = Int32 Function(
    uiOpenTypeFeatures otf,
    Int8 a,
    Int8 b,
    Int8 c,
    Int8 d,
    Uint32 value,
    Pointer<Void> data);
typedef uiNewOpenTypeFeatures_native = uiOpenTypeFeatures Function();
typedef uiNewOpenTypeFeatures_dart = uiOpenTypeFeatures Function();

typedef uiFreeOpenTypeFeatures_native = Void Function(uiOpenTypeFeatures otf);
typedef uiFreeOpenTypeFeatures_dart = void Function(uiOpenTypeFeatures otf);

typedef uiOpenTypeFeaturesClone_native = uiOpenTypeFeatures Function(
    uiOpenTypeFeatures otf);
typedef uiOpenTypeFeaturesClone_dart = uiOpenTypeFeatures Function(
    uiOpenTypeFeatures otf);

typedef uiOpenTypeFeaturesAdd_native = Void Function(
    uiOpenTypeFeatures otf, Int8 a, Int8 b, Int8 c, Int8 d, Uint32 value);
typedef uiOpenTypeFeaturesAdd_dart = void Function(
    uiOpenTypeFeatures otf, int a, int b, int c, int d, int value);

typedef uiOpenTypeFeaturesRemove_native = Void Function(
    uiOpenTypeFeatures otf, Int8 a, Int8 b, Int8 c, Int8 d);
typedef uiOpenTypeFeaturesRemove_dart = void Function(
    uiOpenTypeFeatures otf, int a, int b, int c, int d);

typedef uiOpenTypeFeaturesGet_native = Int32 Function(uiOpenTypeFeatures otf,
    Int8 a, Int8 b, Int8 c, Int8 d, Pointer<Uint32> value);
typedef uiOpenTypeFeaturesGet_dart = int Function(
    uiOpenTypeFeatures otf, int a, int b, int c, int d, Pointer<Uint32> value);

typedef uiOpenTypeFeaturesForEach_native = Void Function(
    uiOpenTypeFeatures otf,
    Pointer<NativeFunction<uiOpenTypeFeaturesForEachFunc_callback>> f,
    Pointer<Void> data);
typedef uiOpenTypeFeaturesForEach_dart = void Function(
    uiOpenTypeFeatures otf,
    Pointer<NativeFunction<uiOpenTypeFeaturesForEachFunc_callback>> f,
    Pointer<Void> data);

typedef uiNewFeaturesAttribute_native = uiAttribute Function(
    uiOpenTypeFeatures otf);
typedef uiNewFeaturesAttribute_dart = uiAttribute Function(
    uiOpenTypeFeatures otf);

typedef uiAttributeFeatures_native = uiOpenTypeFeatures Function(
    uiAttribute a);
typedef uiAttributeFeatures_dart = uiOpenTypeFeatures Function(uiAttribute a);

// --- AttributedString ---
typedef uiAttributedStringForEachAttribute_callback = Int32 Function(
    uiAttributedString s,
    uiAttribute a,
    IntPtr start,
    IntPtr end,
    Pointer<Void> data);
typedef uiNewAttributedString_native = uiAttributedString Function(
    Pointer<Utf8> initialString);
typedef uiNewAttributedString_dart = uiAttributedString Function(
    Pointer<Utf8> initialString);

typedef uiFreeAttributedString_native = Void Function(uiAttributedString s);
typedef uiFreeAttributedString_dart = void Function(uiAttributedString s);

typedef uiAttributedStringString_native = Pointer<Utf8> Function(
    uiAttributedString s);
typedef uiAttributedStringString_dart = Pointer<Utf8> Function(
    uiAttributedString s);

typedef uiAttributedStringLen_native = IntPtr Function(uiAttributedString s);
typedef uiAttributedStringLen_dart = int Function(uiAttributedString s);

typedef uiAttributedStringAppendUnattributed_native = Void Function(
    uiAttributedString s, Pointer<Utf8> str);
typedef uiAttributedStringAppendUnattributed_dart = void Function(
    uiAttributedString s, Pointer<Utf8> str);

typedef uiAttributedStringInsertAtUnattributed_native = Void Function(
    uiAttributedString s, Pointer<Utf8> str, IntPtr at);
typedef uiAttributedStringInsertAtUnattributed_dart = void Function(
    uiAttributedString s, Pointer<Utf8> str, int at);

typedef uiAttributedStringDelete_native = Void Function(
    uiAttributedString s, IntPtr start, IntPtr end);
typedef uiAttributedStringDelete_dart = void Function(
    uiAttributedString s, int start, int end);

typedef uiAttributedStringSetAttribute_native = Void Function(
    uiAttributedString s, uiAttribute a, IntPtr start, IntPtr end);
typedef uiAttributedStringSetAttribute_dart = void Function(
    uiAttributedString s, uiAttribute a, int start, int end);

typedef uiAttributedStringForEachAttribute_native = Void Function(
    uiAttributedString s,
    Pointer<NativeFunction<uiAttributedStringForEachAttribute_callback>> f,
    Pointer<Void> data);
typedef uiAttributedStringForEachAttribute_dart = void Function(
    uiAttributedString s,
    Pointer<NativeFunction<uiAttributedStringForEachAttribute_callback>> f,
    Pointer<Void> data);

typedef uiAttributedStringNumGraphemes_native = IntPtr Function(
    uiAttributedString s);
typedef uiAttributedStringNumGraphemes_dart = int Function(
    uiAttributedString s);

typedef uiAttributedStringByteIndexToGrapheme_native = IntPtr Function(
    uiAttributedString s, IntPtr pos);
typedef uiAttributedStringByteIndexToGrapheme_dart = int Function(
    uiAttributedString s, int pos);

typedef uiAttributedStringGraphemeToByteIndex_native = IntPtr Function(
    uiAttributedString s, IntPtr pos);
typedef uiAttributedStringGraphemeToByteIndex_dart = int Function(
    uiAttributedString s, int pos);

// --- Font ---
typedef uiLoadControlFont_native = Void Function(uiFontDescriptor f);
typedef uiLoadControlFont_dart = void Function(uiFontDescriptor f);

typedef uiFreeFontDescriptor_native = Void Function(uiFontDescriptor desc);
typedef uiFreeFontDescriptor_dart = void Function(uiFontDescriptor desc);

typedef uiDrawNewTextLayout_native = uiDrawTextLayout Function(
    Pointer<uiDrawTextLayoutParamsStruct> params);
typedef uiDrawNewTextLayout_dart = uiDrawTextLayout Function(
    Pointer<uiDrawTextLayoutParamsStruct> params);

typedef uiDrawFreeTextLayout_native = Void Function(uiDrawTextLayout tl);
typedef uiDrawFreeTextLayout_dart = void Function(uiDrawTextLayout tl);

typedef uiDrawText_native = Void Function(
    uiDrawContext c, uiDrawTextLayout tl, Double x, Double y);
typedef uiDrawText_dart = void Function(
    uiDrawContext c, uiDrawTextLayout tl, double x, double y);

typedef uiDrawTextLayoutExtents_native = Void Function(
    uiDrawTextLayout tl, Pointer<Double> width, Pointer<Double> height);
typedef uiDrawTextLayoutExtents_dart = void Function(
    uiDrawTextLayout tl, Pointer<Double> width, Pointer<Double> height);

// --- FontButton ---
typedef uiFontButtonFont_native = Void Function(
    uiFontButton b, uiFontDescriptor desc);
typedef uiFontButtonFont_dart = void Function(
    uiFontButton b, uiFontDescriptor desc);

typedef uiFontButtonOnChanged_callback = Void Function(
    uiFontButton sender, Pointer<Void> senderData);
typedef uiFontButtonOnChanged_native = Void Function(
    uiFontButton b,
    Pointer<NativeFunction<uiFontButtonOnChanged_callback>> f,
    Pointer<Void> data);
typedef uiFontButtonOnChanged_dart = void Function(
    uiFontButton b,
    Pointer<NativeFunction<uiFontButtonOnChanged_callback>> f,
    Pointer<Void> data);

typedef uiNewFontButton_native = uiFontButton Function();
typedef uiNewFontButton_dart = uiFontButton Function();

typedef uiFreeFontButtonFont_native = Void Function(uiFontDescriptor desc);
typedef uiFreeFontButtonFont_dart = void Function(uiFontDescriptor desc);

// --- ColorButton ---
typedef uiColorButtonColor_native = Void Function(uiColorButton b,
    Pointer<Double> r, Pointer<Double> g, Pointer<Double> bl, Pointer<Double> a);
typedef uiColorButtonColor_dart = void Function(uiColorButton b,
    Pointer<Double> r, Pointer<Double> g, Pointer<Double> bl, Pointer<Double> a);

typedef uiColorButtonSetColor_native = Void Function(
    uiColorButton b, Double r, Double g, Double bl, Double a);
typedef uiColorButtonSetColor_dart = void Function(
    uiColorButton b, double r, double g, double bl, double a);

typedef uiColorButtonOnChanged_callback = Void Function(
    uiColorButton sender, Pointer<Void> senderData);
typedef uiColorButtonOnChanged_native = Void Function(
    uiColorButton b,
    Pointer<NativeFunction<uiColorButtonOnChanged_callback>> f,
    Pointer<Void> data);
typedef uiColorButtonOnChanged_dart = void Function(
    uiColorButton b,
    Pointer<NativeFunction<uiColorButtonOnChanged_callback>> f,
    Pointer<Void> data);

typedef uiNewColorButton_native = uiColorButton Function();
typedef uiNewColorButton_dart = uiColorButton Function();

// --- Form ---
typedef uiFormAppend_native = Void Function(
    uiForm f, Pointer<Utf8> label, uiControl c, Int32 stretchy);
typedef uiFormAppend_dart = void Function(
    uiForm f, Pointer<Utf8> label, uiControl c, int stretchy);

typedef uiFormNumChildren_native = Int32 Function(uiForm f);
typedef uiFormNumChildren_dart = int Function(uiForm f);

typedef uiFormDelete_native = Void Function(uiForm f, Int32 index);
typedef uiFormDelete_dart = void Function(uiForm f, int index);

typedef uiFormPadded_native = Int32 Function(uiForm f);
typedef uiFormPadded_dart = int Function(uiForm f);

typedef uiFormSetPadded_native = Void Function(uiForm f, Int32 padded);
typedef uiFormSetPadded_dart = void Function(uiForm f, int padded);

typedef uiNewForm_native = uiForm Function();
typedef uiNewForm_dart = uiForm Function();

// --- Grid ---
typedef uiGridAppend_native = Void Function(
    uiGrid g,
    uiControl c,
    Int32 left,
    Int32 top,
    Int32 xspan,
    Int32 yspan,
    Int32 hexpand,
    Int32 halign,
    Int32 vexpand,
    Int32 valign);
typedef uiGridAppend_dart = void Function(
    uiGrid g,
    uiControl c,
    int left,
    int top,
    int xspan,
    int yspan,
    int hexpand,
    int halign,
    int vexpand,
    int valign);

typedef uiGridInsertAt_native = Void Function(
    uiGrid g,
    uiControl c,
    uiControl existing,
    Int32 at,
    Int32 xspan,
    Int32 yspan,
    Int32 hexpand,
    Int32 halign,
    Int32 vexpand,
    Int32 valign);
typedef uiGridInsertAt_dart = void Function(
    uiGrid g,
    uiControl c,
    uiControl existing,
    int at,
    int xspan,
    int yspan,
    int hexpand,
    int halign,
    int vexpand,
    int valign);

typedef uiGridPadded_native = Int32 Function(uiGrid g);
typedef uiGridPadded_dart = int Function(uiGrid g);

typedef uiGridSetPadded_native = Void Function(uiGrid g, Int32 padded);
typedef uiGridSetPadded_dart = void Function(uiGrid g, int padded);

typedef uiNewGrid_native = uiGrid Function();
typedef uiNewGrid_dart = uiGrid Function();

// --- Image ---
typedef uiNewImage_native = uiImage Function(Double width, Double height);
typedef uiNewImage_dart = uiImage Function(double width, double height);

typedef uiFreeImage_native = Void Function(uiImage i);
typedef uiFreeImage_dart = void Function(uiImage i);

typedef uiImageAppend_native = Void Function(
    uiImage i, Pointer<Void> pixels, Int32 pixelWidth, Int32 pixelHeight, Int32 byteStride);
typedef uiImageAppend_dart = void Function(
    uiImage i, Pointer<Void> pixels, int pixelWidth, int pixelHeight, int byteStride);

// --- Table Value ---
typedef uiFreeTableValue_native = Void Function(uiTableValue v);
typedef uiFreeTableValue_dart = void Function(uiTableValue v);

typedef uiTableValueGetType_native = Int32 Function(uiTableValue v);
typedef uiTableValueGetType_dart = int Function(uiTableValue v);

typedef uiNewTableValueString_native = uiTableValue Function(Pointer<Utf8> str);
typedef uiNewTableValueString_dart = uiTableValue Function(Pointer<Utf8> str);

typedef uiTableValueString_native = Pointer<Utf8> Function(uiTableValue v);
typedef uiTableValueString_dart = Pointer<Utf8> Function(uiTableValue v);

typedef uiNewTableValueImage_native = uiTableValue Function(uiImage img);
typedef uiNewTableValueImage_dart = uiTableValue Function(uiImage img);

typedef uiTableValueImage_native = uiImage Function(uiTableValue v);
typedef uiTableValueImage_dart = uiImage Function(uiTableValue v);

typedef uiNewTableValueInt_native = uiTableValue Function(Int32 i);
typedef uiNewTableValueInt_dart = uiTableValue Function(int i);

typedef uiTableValueInt_native = Int32 Function(uiTableValue v);
typedef uiTableValueInt_dart = int Function(uiTableValue v);

typedef uiNewTableValueColor_native = uiTableValue Function(
    Double r, Double g, Double b, Double a);
typedef uiNewTableValueColor_dart = uiTableValue Function(
    double r, double g, double b, double a);

typedef uiTableValueColor_native = Void Function(uiTableValue v, Pointer<Double> r,
    Pointer<Double> g, Pointer<Double> b, Pointer<Double> a);
typedef uiTableValueColor_dart = void Function(uiTableValue v, Pointer<Double> r,
    Pointer<Double> g, Pointer<Double> b, Pointer<Double> a);

// --- Table Model ---
typedef uiNewTableModel_native = uiTableModel Function(uiTableModelHandler mh);
typedef uiNewTableModel_dart = uiTableModel Function(uiTableModelHandler mh);

typedef uiFreeTableModel_native = Void Function(uiTableModel m);
typedef uiFreeTableModel_dart = void Function(uiTableModel m);

typedef uiTableModelRowInserted_native = Void Function(
    uiTableModel m, Int32 newIndex);
typedef uiTableModelRowInserted_dart = void Function(
    uiTableModel m, int newIndex);

typedef uiTableModelRowChanged_native = Void Function(
    uiTableModel m, Int32 index);
typedef uiTableModelRowChanged_dart = void Function(uiTableModel m, int index);

typedef uiTableModelRowDeleted_native = Void Function(
    uiTableModel m, Int32 oldIndex);
typedef uiTableModelRowDeleted_dart = void Function(
    uiTableModel m, int oldIndex);

// --- Table ---
typedef uiTableAppendTextColumn_native = Void Function(
    uiTable t,
    Pointer<Utf8> name,
    Int32 textModelColumn,
    Int32 textEditableModelColumn,
    Pointer<uiTableTextColumnOptionalParamsStruct> textParams);
typedef uiTableAppendTextColumn_dart = void Function(
    uiTable t,
    Pointer<Utf8> name,
    int textModelColumn,
    int textEditableModelColumn,
    Pointer<uiTableTextColumnOptionalParamsStruct> textParams);

typedef uiTableAppendImageColumn_native = Void Function(
    uiTable t, Pointer<Utf8> name, Int32 imageModelColumn);
typedef uiTableAppendImageColumn_dart = void Function(
    uiTable t, Pointer<Utf8> name, int imageModelColumn);

typedef uiTableAppendImageTextColumn_native = Void Function(
    uiTable t,
    Pointer<Utf8> name,
    Int32 imageModelColumn,
    Int32 textModelColumn,
    Int32 textEditableModelColumn,
    Pointer<uiTableTextColumnOptionalParamsStruct> textParams);
typedef uiTableAppendImageTextColumn_dart = void Function(
    uiTable t,
    Pointer<Utf8> name,
    int imageModelColumn,
    int textModelColumn,
    int textEditableModelColumn,
    Pointer<uiTableTextColumnOptionalParamsStruct> textParams);

typedef uiTableAppendCheckboxColumn_native = Void Function(
    uiTable t,
    Pointer<Utf8> name,
    Int32 checkboxModelColumn,
    Int32 checkboxEditableModelColumn);
typedef uiTableAppendCheckboxColumn_dart = void Function(
    uiTable t,
    Pointer<Utf8> name,
    int checkboxModelColumn,
    int checkboxEditableModelColumn);

typedef uiTableAppendCheckboxTextColumn_native = Void Function(
    uiTable t,
    Pointer<Utf8> name,
    Int32 checkboxModelColumn,
    Int32 checkboxEditableModelColumn,
    Int32 textModelColumn,
    Int32 textEditableModelColumn,
    Pointer<uiTableTextColumnOptionalParamsStruct> textParams);
typedef uiTableAppendCheckboxTextColumn_dart = void Function(
    uiTable t,
    Pointer<Utf8> name,
    int checkboxModelColumn,
    int checkboxEditableModelColumn,
    int textModelColumn,
    int textEditableModelColumn,
    Pointer<uiTableTextColumnOptionalParamsStruct> textParams);

typedef uiTableAppendProgressBarColumn_native = Void Function(
    uiTable t, Pointer<Utf8> name, Int32 progressModelColumn);
typedef uiTableAppendProgressBarColumn_dart = void Function(
    uiTable t, Pointer<Utf8> name, int progressModelColumn);

typedef uiTableAppendButtonColumn_native = Void Function(
    uiTable t,
    Pointer<Utf8> name,
    Int32 buttonModelColumn,
    Int32 buttonClickableModelColumn);
typedef uiTableAppendButtonColumn_dart = void Function(
    uiTable t,
    Pointer<Utf8> name,
    int buttonModelColumn,
    int buttonClickableModelColumn);

typedef uiTableHeaderVisible_native = Int32 Function(uiTable t);
typedef uiTableHeaderVisible_dart = int Function(uiTable t);

typedef uiTableHeaderSetVisible_native = Void Function(uiTable t, Int32 visible);
typedef uiTableHeaderSetVisible_dart = void Function(uiTable t, int visible);

typedef uiNewTable_native = uiTable Function(
    Pointer<uiTableParamsStruct> params);
typedef uiNewTable_dart = uiTable Function(Pointer<uiTableParamsStruct> params);

typedef uiTableOnRowClicked_callback = Void Function(
    uiTable t, Int32 row, Pointer<Void> data);
typedef uiTableOnRowClicked_native = Void Function(uiTable t,
    Pointer<NativeFunction<uiTableOnRowClicked_callback>> f, Pointer<Void> data);
typedef uiTableOnRowClicked_dart = void Function(uiTable t,
    Pointer<NativeFunction<uiTableOnRowClicked_callback>> f, Pointer<Void> data);

typedef uiTableOnRowDoubleClicked_callback = Void Function(
    uiTable t, Int32 row, Pointer<Void> data);
typedef uiTableOnRowDoubleClicked_native = Void Function(
    uiTable t,
    Pointer<NativeFunction<uiTableOnRowDoubleClicked_callback>> f,
    Pointer<Void> data);
typedef uiTableOnRowDoubleClicked_dart = void Function(
    uiTable t,
    Pointer<NativeFunction<uiTableOnRowDoubleClicked_callback>> f,
    Pointer<Void> data);

typedef uiTableHeaderSetSortIndicator_native = Void Function(
    uiTable t, Int32 column, Int32 indicator);
typedef uiTableHeaderSetSortIndicator_dart = void Function(
    uiTable t, int column, int indicator);

typedef uiTableHeaderSortIndicator_native = Int32 Function(
    uiTable t, Int32 column);
typedef uiTableHeaderSortIndicator_dart = int Function(uiTable t, int column);

typedef uiTableHeaderOnClicked_callback = Void Function(
    uiTable sender, Int32 column, Pointer<Void> senderData);
typedef uiTableHeaderOnClicked_native = Void Function(
    uiTable t,
    Pointer<NativeFunction<uiTableHeaderOnClicked_callback>> f,
    Pointer<Void> data);
typedef uiTableHeaderOnClicked_dart = void Function(
    uiTable t,
    Pointer<NativeFunction<uiTableHeaderOnClicked_callback>> f,
    Pointer<Void> data);

typedef uiTableColumnWidth_native = Int32 Function(uiTable t, Int32 column);
typedef uiTableColumnWidth_dart = int Function(uiTable t, int column);

typedef uiTableColumnSetWidth_native = Void Function(
    uiTable t, Int32 column, Int32 width);
typedef uiTableColumnSetWidth_dart = void Function(
    uiTable t, int column, int width);

typedef uiTableGetSelectionMode_native = Int32 Function(uiTable t);
typedef uiTableGetSelectionMode_dart = int Function(uiTable t);

typedef uiTableSetSelectionMode_native = Void Function(
    uiTable t, Int32 mode);
typedef uiTableSetSelectionMode_dart = void Function(
    uiTable t, int mode);

typedef uiTableOnSelectionChanged_callback = Void Function(
    uiTable t, Pointer<Void> data);
typedef uiTableOnSelectionChanged_native = Void Function(
    uiTable t,
    Pointer<NativeFunction<uiTableOnSelectionChanged_callback>> f,
    Pointer<Void> data);
typedef uiTableOnSelectionChanged_dart = void Function(
    uiTable t,
    Pointer<NativeFunction<uiTableOnSelectionChanged_callback>> f,
    Pointer<Void> data);

typedef uiTableGetSelection_native = uiTableSelection Function(uiTable t);
typedef uiTableGetSelection_dart = uiTableSelection Function(uiTable t);

typedef uiTableSetSelection_native = Void Function(
    uiTable t, uiTableSelection sel);
typedef uiTableSetSelection_dart = void Function(
    uiTable t, uiTableSelection sel);

typedef uiFreeTableSelection_native = Void Function(uiTableSelection s);
typedef uiFreeTableSelection_dart = void Function(uiTableSelection s);