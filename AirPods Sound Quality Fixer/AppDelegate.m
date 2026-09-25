#import "AppDelegate.h"
#import <CoreAudio/CoreAudio.h>
#import <ServiceManagement/ServiceManagement.h>


@interface AppDelegate ( )
{
    BOOL paused;
    NSMenu* menu;
    NSStatusItem* statusItem;
    AudioDeviceID forcedInputID;
    NSUserDefaults* defaults;
    NSMutableDictionary* itemsToIDS;
    NSMenuItem *startupItem;
}

@property (weak) IBOutlet NSWindow *window;

@end


@implementation AppDelegate


static AudioObjectPropertyAddress propertyAddress( AudioObjectPropertySelector selector , AudioObjectPropertyScope scope )
{
    return ( AudioObjectPropertyAddress ) { selector , scope , kAudioObjectPropertyElementMain };
}


static AudioObjectPropertyAddress defaultInputDeviceAddress( void )
{
    return propertyAddress( kAudioHardwarePropertyDefaultInputDevice , kAudioObjectPropertyScopeGlobal );
}


static BOOL isBuiltInDevice( AudioDeviceID deviceID )
{
    UInt32 transportType = 0;
    UInt32 size = sizeof( transportType );
    AudioObjectPropertyAddress address = propertyAddress( kAudioDevicePropertyTransportType , kAudioObjectPropertyScopeGlobal );
    AudioObjectGetPropertyData( deviceID , &address , 0 , NULL , &size , &transportType );
    return transportType == kAudioDeviceTransportTypeBuiltIn;
}


static void setDefaultInputDevice( AudioDeviceID deviceID )
{
    AudioObjectPropertyAddress address = defaultInputDeviceAddress( );
    AudioObjectSetPropertyData( kAudioObjectSystemObject , &address , 0 , NULL , sizeof( deviceID ) , &deviceID );
}


- ( void ) applicationDidFinishLaunching : ( NSNotification* ) aNotification
{

    defaults = [ NSUserDefaults standardUserDefaults ];
    
    itemsToIDS = [ NSMutableDictionary dictionary ];
    
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSInteger readenId = [prefs integerForKey: @"Device"];
    
    if (readenId == 0) {
        [prefs setInteger:UINT32_MAX forKey: @"Device"];
        [prefs synchronize];
    }
    
    forcedInputID = readenId == 0 ? UINT32_MAX : ( AudioDeviceID ) readenId;
    
    NSLog(@"Loaded device from UserDefaults: %u", forcedInputID);

    NSImage* image = [ NSImage imageNamed : @"airpods-icon" ];
    [ image setTemplate : YES ];

    statusItem = [ [ NSStatusBar systemStatusBar ] statusItemWithLength : NSVariableStatusItemLength ];
    statusItem.button.toolTip = @"AirPods Audio Quality & Battery Life Fixer";
    statusItem.button.image = image;

    // listDevices rebuilds the menu, so the listener has to run on the main queue

    __weak AppDelegate* weakSelf = self;
    AudioObjectPropertyAddress inputDeviceAddress = defaultInputDeviceAddress( );

    AudioObjectAddPropertyListenerBlock(
        kAudioObjectSystemObject,
        &inputDeviceAddress,
        dispatch_get_main_queue( ),
        ^( UInt32 inNumberAddresses , const AudioObjectPropertyAddress* inAddresses )
        {
            NSLog( @"default input device changed" );
            [ weakSelf listDevices ];
        } );

     [ self listDevices ];
    
}


- ( void ) deviceSelected : ( NSMenuItem* ) item
{

    NSNumber* number = itemsToIDS[ item.title ];
    
    if ( number != nil )
    {
    
        AudioDeviceID newId = [ number unsignedIntValue ];
        
        NSLog( @"switching to new device : %u" , newId );
        
        forcedInputID = newId;
        
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        [prefs setInteger:newId forKey: @"Device"];
        [prefs synchronize];
        NSLog(@"Saved device from UserDefaults: %u", forcedInputID);

        setDefaultInputDevice( forcedInputID );
        
        // show forcing

        [ menu
            insertItemWithTitle : @"forcing..."
            action : NULL
            keyEquivalent : @""
            atIndex : 2 ];

    }
    
}


- ( void ) listDevices
{

    NSDictionary *bundleInfo = [ [ NSBundle mainBundle] infoDictionary];
    NSString *versionString = [ NSString stringWithFormat : @"Version %@ (build %@)",
                               bundleInfo[ @"CFBundleShortVersionString" ],
                               bundleInfo[ @"CFBundleVersion"] ];

    menu = [ [ NSMenu alloc ] init ];
    menu.delegate = self;
    [ menu addItemWithTitle : versionString action : nil keyEquivalent : @"" ];
    [ menu addItem : [ NSMenuItem separatorItem ] ]; // A thin grey line
    
    NSMenuItem* item =  [ menu
            addItemWithTitle : NSLocalizedString(@"Pause", @"Pause")
            action : @selector(manualPause:)
            keyEquivalent : @"" ];

    if ( paused ) [ item setState : NSControlStateValueOn ];

    [ menu addItem : [ NSMenuItem separatorItem ] ]; // A thin grey line
    [ menu addItemWithTitle : @"Forced input:" action : nil keyEquivalent : @"" ];
    
    UInt32 propertySize = 0;
    AudioObjectPropertyAddress devicesAddress = propertyAddress( kAudioHardwarePropertyDevices , kAudioObjectPropertyScopeGlobal );
    
    AudioObjectGetPropertyDataSize(
        kAudioObjectSystemObject ,
        &devicesAddress ,
        0 ,
        NULL ,
        &propertySize );
    
    NSMutableData* devices = [ NSMutableData dataWithLength : propertySize ];
    AudioDeviceID* dev_array = devices.mutableBytes;
    
    if ( AudioObjectGetPropertyData(
            kAudioObjectSystemObject ,
            &devicesAddress ,
            0 ,
            NULL ,
            &propertySize ,
            dev_array ) != noErr ) propertySize = 0;
    
    int numberOfDevices = ( int ) ( propertySize / sizeof( AudioDeviceID ) );
    
    NSLog( @"devices found : %i" , numberOfDevices );
    
    if ( forcedInputID < UINT32_MAX )
    {
    
        char found = 0;

        for( int index = 0 ;
                 index < numberOfDevices ;
                 index++ )
        {
        
            if ( dev_array[ index] == forcedInputID ) found = 1;
        
        }
        
        if ( found == 0 )
        {
            NSLog( @"force input not found in device list" );
            forcedInputID = UINT32_MAX;
        }
        else NSLog( @"force input found in device list" );
        
    }


    for( int index = 0 ;
             index < numberOfDevices ;
             index++ )
    {
    
        AudioDeviceID oneDeviceID = dev_array[ index ];

        propertySize = 0;
        AudioObjectPropertyAddress streamsAddress = propertyAddress( kAudioDevicePropertyStreams , kAudioObjectPropertyScopeInput );
        
        AudioObjectGetPropertyDataSize(
            oneDeviceID ,
            &streamsAddress ,
            0 ,
            NULL ,
            &propertySize );

        // if there are any input streams, then it is an input

        if ( propertySize > 0 )
        {
        
            // get name

            CFStringRef deviceName = NULL;
            propertySize = sizeof( deviceName );
            AudioObjectPropertyAddress nameAddress = propertyAddress( kAudioObjectPropertyName , kAudioObjectPropertyScopeGlobal );
            
            AudioObjectGetPropertyData(
                oneDeviceID ,
                &nameAddress ,
                0 ,
                NULL ,
                &propertySize ,
                &deviceName );

            NSString* nameStr = CFBridgingRelease( deviceName );

            if ( nameStr == nil ) continue;

            NSLog( @"found input device : %@  %u" , nameStr , (unsigned int)oneDeviceID );

            if ( forcedInputID == UINT32_MAX && isBuiltInDevice( oneDeviceID ) )
            {

                // if there is no forced device yet, select "built-in" by default

                NSLog( @"setting forced device : %@  %u" , nameStr , (unsigned int)oneDeviceID );

                forcedInputID = oneDeviceID;
                
            }

            NSMenuItem* item = [ menu
                addItemWithTitle : nameStr
                action : @selector(deviceSelected:)
                keyEquivalent : @"" ];
            
            if ( oneDeviceID == forcedInputID )
            {
                [ item setState : NSControlStateValueOn ];
                NSLog( @"setting device selected : %@  %u" , nameStr , (unsigned int)oneDeviceID );
            }
            
            itemsToIDS[ nameStr ] = [ NSNumber numberWithUnsignedInt : oneDeviceID];

        }

        [ statusItem setMenu : menu ];

    }

    // get current input device
    
    AudioDeviceID deviceID = kAudioDeviceUnknown;

    // get the default output device
    // if it is not the built in, change
    
    propertySize = sizeof( deviceID );
    AudioObjectPropertyAddress inputAddress = defaultInputDeviceAddress( );
    
    AudioObjectGetPropertyData(
        kAudioObjectSystemObject ,
        &inputAddress ,
        0 ,
        NULL ,
        &propertySize ,
        &deviceID );
    
    NSLog( @"default input device is %u" , deviceID );
    
    if ( !paused && forcedInputID != UINT32_MAX && deviceID != forcedInputID )
    {

        NSLog( @"forcing input device for default : %u" , forcedInputID );

        setDefaultInputDevice( forcedInputID );
        
        // show forcing

        [ menu
            insertItemWithTitle : @"forcing..."
            action : NULL
            keyEquivalent : @""
            atIndex : 2 ];

    }
    
    [ menu addItem : [ NSMenuItem separatorItem ] ]; // A thin grey line

    startupItem = [ menu
        addItemWithTitle : @"Open at login"
        action : @selector(toggleStartupItem)
        keyEquivalent : @"" ];
    
    [ menu addItem : [ NSMenuItem separatorItem ] ]; // A thin grey line

    [ menu addItem : [ NSMenuItem separatorItem ] ]; // A thin grey line
    [ menu addItemWithTitle : @"Donate if you like the app"
           action : @selector(support)
           keyEquivalent : @"" ];

    [ menu addItemWithTitle : @"Check for updates"
           action : @selector(update)
           keyEquivalent : @"" ];
    
    [ menu addItemWithTitle : @"Hide"
           action : @selector(hide)
           keyEquivalent : @"" ];
    
    [ menu addItemWithTitle : @"Quit"
           action : @selector(terminate)
           keyEquivalent : @"" ];

}

- ( void ) manualPause : ( NSMenuItem* ) item
{
    paused = !paused;
    [ self listDevices ];
}

- ( void ) terminate
{
    [ NSApp terminate : nil ];
}

- ( void ) support
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: @"https://paypal.me/milgra"]];
}

- ( void ) update
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: @"http://milgra.com/airpods-sound-quality-fixer.html"]];
}

- ( void ) hide
{
    [statusItem setVisible:false];
}

- (void)toggleStartupItem
{
    SMAppService *service = SMAppService.mainAppService;
    NSError *error = nil;
    BOOL succeeded = service.status == SMAppServiceStatusEnabled
        ? [service unregisterAndReturnError:&error]
        : [service registerAndReturnError:&error];

    if ( !succeeded )
    {
        NSLog(@"Updating login item failed: %@", error);
    }

    if ( service.status == SMAppServiceStatusRequiresApproval )
    {
        [SMAppService openSystemSettingsLoginItems];
    }
    
    [self updateStartupItemState];
}

- (void)updateStartupItemState
{
    [startupItem setState: SMAppService.mainAppService.status == SMAppServiceStatusEnabled ? NSControlStateValueOn : NSControlStateValueOff];
}

- (void)menuWillOpen:(NSMenu *)menu
{
    [self updateStartupItemState];
}

@end
