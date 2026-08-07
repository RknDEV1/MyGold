#import "MyGoldAPI.h"
#import "MyGoldConfig.h"

#import <CommonCrypto/CommonDigest.h>
#import <sys/utsname.h>
#import <sys/socket.h>
#import <sys/ioctl.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

@implementation MyGoldAPI {
    UIWindow *_overlayWindow;
    BOOL _isAuthorized;
}

+ (instancetype)sharedInstance {
    static MyGoldAPI *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        sharedInstance.keyName = @"Desconhecido";
        sharedInstance.keyExpiry = @"0";
        sharedInstance.keyVersion = @"1.0";
        sharedInstance.packagerStatus = @"OFFLINE";
        sharedInstance.currentHWID = nil;
        sharedInstance->_isAuthorized = NO;
    });
    return sharedInstance;
}

- (NSString *)decryptString:(const char *)bytes length:(int)len {
    const char *key = kMyGoldXORKey;
    int keyLen = (int)strlen(key);
    NSMutableString *decrypted = [NSMutableString string];
    for (int i = 0; i < len; i++) {
        [decrypted appendFormat:@"%c", bytes[i] ^ key[i % keyLen]];
    }
    return decrypted;
}

- (NSString *)getHWID {
    NSString *identifierForVendor = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    NSString *combined = [NSString stringWithFormat:@"%@%@", identifierForVendor, deviceModel];
    const char *cStr = [combined UTF8String];
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(cStr, (CC_LONG)strlen(cStr), result);
    
    NSMutableString *hash = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x", result[i]];
    }
    self.currentHWID = hash;
    return hash;
}

- (NSString *)getLocalIP {
    NSString *ip = @"127.0.0.1";
    struct ifaddrs *addrs;
    if (getifaddrs(&addrs) == 0) {
        struct ifaddrs *addr = addrs;
        while (addr) {
            if (addr->ifa_addr && addr->ifa_addr->sa_family == AF_INET &&
                strcmp(addr->ifa_name, "lo0") != 0) {
                ip = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)addr->ifa_addr)->sin_addr)];
                break;
            }
            addr = addr->ifa_next;
        }
        freeifaddrs(addrs);
    }
    return ip;
}

- (void)startLoginFlow {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *savedKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"saved_license_key"];
        if (savedKey && savedKey.length > 0) {
            [self doLoginWithKey:savedKey completion:^(BOOL success, NSString *message) {
                if (success) {
                    return;
                } else {
                    [self showUDIDPopup];
                }
            }];
        } else {
            [self showUDIDPopup];
        }
    });
}

- (void)showUDIDPopup {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_overlayWindow) {
            [_overlayWindow removeFromSuperview];
            _overlayWindow = nil;
        }
        
        UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.windowLevel = UIWindowLevelAlert + 1;
        _overlayWindow = window;
        
        UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
        overlay.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.95];
        
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = overlay.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [overlay addSubview:blurView];
        
        CGFloat width = 320;
        CGFloat height = 400;
        CGFloat centerX = (UIScreen.mainScreen.bounds.size.width - width) / 2;
        CGFloat centerY = (UIScreen.mainScreen.bounds.size.height - height) / 2;
        
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(centerX, centerY, width, height)];
        card.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
        card.layer.cornerRadius = 24;
        card.layer.borderColor = [UIColor colorWithRed:0.95 green:0.62 blue:0.04 alpha:1.0].CGColor;
        card.layer.borderWidth = 1.0;
        card.clipsToBounds = YES;
        
        UIView *headerBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 60)];
        headerBar.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
        
        UILabel *crownIcon = [[UILabel alloc] initWithFrame:CGRectMake(20, 14, 32, 32)];
        crownIcon.text = @"👑";
        crownIcon.font = [UIFont systemFontOfSize:22];
        crownIcon.textAlignment = NSTextAlignmentCenter;
        [headerBar addSubview:crownIcon];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 16, 200, 28)];
        titleLabel.text = @"MY GOLD";
        titleLabel.font = [UIFont boldSystemFontOfSize:18];
        titleLabel.textColor = [UIColor colorWithRed:0.95 green:0.62 blue:0.04 alpha:1.0];
        [headerBar addSubview:titleLabel];
        
        [card addSubview:headerBar];
        
        CGFloat startY = 75;
        
        UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(20, startY, width - 40, 18)];
        subtitle.text = @"Extração de Dispositivo";
        subtitle.font = [UIFont boldSystemFontOfSize:12];
        subtitle.textColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1.0];
        subtitle.textAlignment = NSTextAlignmentCenter;
        [card addSubview:subtitle];
        
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        spinner.center = CGPointMake(width / 2, startY + 70);
        [spinner startAnimating];
        [card addSubview:spinner];
        
        UILabel *loadingText = [[UILabel alloc] initWithFrame:CGRectMake(20, startY + 110, width - 40, 16)];
        loadingText.text = @"Extraindo UDID do dispositivo...";
        loadingText.font = [UIFont systemFontOfSize:12];
        loadingText.textColor = [UIColor colorWithRed:0.6 green:0.6 blue:0.6 alpha:1.0];
        loadingText.textAlignment = NSTextAlignmentCenter;
        [card addSubview:loadingText];
        
        CGFloat fieldStartY = startY + 155;
        CGFloat fieldWidth = width - 40;
        CGFloat fieldX = 20;
        
        UILabel *devModelLabel = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, fieldStartY, fieldWidth, 12)];
        devModelLabel.text = @"DISPOSITIVO";
        devModelLabel.font = [UIFont boldSystemFontOfSize:8];
        devModelLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
        [card addSubview:devModelLabel];
        
        UILabel *devModelValue = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, fieldStartY + 14, fieldWidth, 16)];
        devModelValue.font = [UIFont boldSystemFontOfSize:12];
        devModelValue.textColor = [UIColor whiteColor];
        devModelValue.text = @"Detectando...";
        [card addSubview:devModelValue];
        
        UILabel *iosLabel = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, fieldStartY + 38, fieldWidth, 12)];
        iosLabel.text = @"VERSÃO iOS";
        iosLabel.font = [UIFont boldSystemFontOfSize:8];
        iosLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
        [card addSubview:iosLabel];
        
        UILabel *iosValue = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, fieldStartY + 52, fieldWidth, 16)];
        iosValue.font = [UIFont boldSystemFontOfSize:12];
        iosValue.textColor = [UIColor whiteColor];
        iosValue.text = @"Detectando...";
        [card addSubview:iosValue];
        
        UILabel *hwidLabel = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, fieldStartY + 76, fieldWidth, 12)];
        hwidLabel.text = @"HWID (UDID)";
        hwidLabel.font = [UIFont boldSystemFontOfSize:8];
        hwidLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
        [card addSubview:hwidLabel];
        
        UILabel *hwidValue = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, fieldStartY + 90, fieldWidth, 28)];
        hwidValue.font = [UIFont systemFontOfSize:10];
        hwidValue.textColor = [UIColor colorWithRed:0.95 green:0.62 blue:0.04 alpha:1.0];
        hwidValue.numberOfLines = 2;
        hwidValue.text = @"Calculando...";
        [card addSubview:hwidValue];
        
        UIView *statusDot = [[UIView alloc] initWithFrame:CGRectMake(fieldX, fieldStartY + 135, 8, 8)];
        statusDot.backgroundColor = [UIColor yellowColor];
        statusDot.layer.cornerRadius = 4;
        [card addSubview:statusDot];
        
        UILabel *statusText = [[UILabel alloc] initWithFrame:CGRectMake(fieldX + 14, fieldStartY + 132, fieldWidth - 14, 14)];
        statusText.text = @"Processando extração...";
        statusText.font = [UIFont boldSystemFontOfSize:10];
        statusText.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.0 alpha:1.0];
        [card addSubview:statusText];
        
        UIButton *continueBtn = [[UIButton alloc] initWithFrame:CGRectMake(20, height - 65, width - 40, 48)];
        continueBtn.backgroundColor = [UIColor colorWithRed:0.95 green:0.62 blue:0.04 alpha:1.0];
        continueBtn.layer.cornerRadius = 14;
        continueBtn.enabled = NO;
        continueBtn.alpha = 0.4;
        
        UILabel *btnLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width - 40, 48)];
        btnLabel.text = @"Continuar →";
        btnLabel.font = [UIFont boldSystemFontOfSize:14];
        btnLabel.textColor = [UIColor blackColor];
        btnLabel.textAlignment = NSTextAlignmentCenter;
        [continueBtn addSubview:btnLabel];
        
        [continueBtn addTarget:self action:@selector(continueToLoginPopup) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:continueBtn];
        
        [overlay addSubview:card];
        window.rootViewController = [[UIViewController alloc] init];
        [window.rootViewController.view addSubview:overlay];
        [window makeKeyAndVisible];
        
        [self performExtractionWithCompletion:^(NSString *deviceModel, NSString *iosVersion, NSString *hwid, NSString *shortHWID) {
            devModelValue.text = deviceModel ?: @"Desconhecido";
            iosValue.text = iosVersion ?: @"N/A";
            hwidValue.text = shortHWID ?: @"N/A";
            
            [spinner stopAnimating];
            spinner.hidden = YES;
            loadingText.text = @"Extração concluída!";
            loadingText.textColor = [UIColor colorWithRed:0.3 green:0.9 blue:0.3 alpha:1.0];
            
            statusDot.backgroundColor = [UIColor colorWithRed:0.3 green:0.9 blue:0.3 alpha:1.0];
            statusText.text = @"Dispositivo identificado com sucesso";
            statusText.textColor = [UIColor colorWithRed:0.3 green:0.9 blue:0.3 alpha:1.0];
            
            continueBtn.enabled = YES;
            continueBtn.alpha = 1.0;
            
            [self registerUDIDWithCompletion:^(BOOL success) {
                if (!success) {
                    statusDot.backgroundColor = [UIColor yellowColor];
                    statusText.text = @"Registro salvo localmente (offline)";
                    statusText.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.0 alpha:1.0];
                }
            }];
        }];
    });
}

- (void)performExtractionWithCompletion:(void (^)(NSString *deviceModel, NSString *iosVersion, NSString *hwid, NSString *shortHWID))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        struct utsname systemInfo;
        uname(&systemInfo);
        NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
        NSString *iosVersion = [[UIDevice currentDevice] systemVersion];
        NSString *hwid = [self getHWID];
        NSString *shortHWID = [NSString stringWithFormat:@"%@...%@", [hwid substringToIndex:8], [hwid substringFromIndex:hwid.length - 4]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(deviceModel, iosVersion, hwid, shortHWID);
        });
    });
}

- (void)registerUDIDWithCompletion:(void (^)(BOOL success))completion {
    NSString *hwid = [self currentHWID];
    NSString *product = [UIDevice currentDevice].model;
    NSString *version = [[UIDevice currentDevice] systemVersion];
    NSString *serial = @"N/A";
    NSString *ip = [self getLocalIP];
    
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    NSString *apiUrl = kMyGoldAPIUrl;
    NSString *packageId = kMyGoldPackageID;
    NSString *packageToken = kMyGoldPackageToken;
    
    NSDictionary *jsonDict = @{
        @"hwid": hwid ?: @"",
        @"device_model": deviceModel ?: @"",
        @"product": product ?: @"",
        @"version": version ?: @"",
        @"serial": serial ?: @"",
        @"ip": ip ?: @"",
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&error];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:apiUrl]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:packageId forHTTPHeaderField:@"X-Package-ID"];
    [request setValue:packageToken forHTTPHeaderField:@"X-Package-Token"];
    [request setHTTPBody:jsonData];
    [request setTimeoutInterval:10.0];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        BOOL success = (error == nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(success);
        });
    }];
    [task resume];
}

- (void)continueToLoginPopup {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_overlayWindow) {
            [_overlayWindow removeFromSuperview];
            _overlayWindow = nil;
        }
        [self showLoginPopup];
    });
}

- (void)showLoginPopup {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_overlayWindow) {
            [_overlayWindow removeFromSuperview];
            _overlayWindow = nil;
        }
        
        UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.windowLevel = UIWindowLevelAlert + 1;
        _overlayWindow = window;
        
        UIView *overlay = [[UIView alloc] initWithFrame:window.bounds];
        overlay.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.95];
        
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = overlay.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [overlay addSubview:blurView];
        
        CGFloat width = 320;
        CGFloat height = 440;
        CGFloat centerX = (UIScreen.mainScreen.bounds.size.width - width) / 2;
        CGFloat centerY = (UIScreen.mainScreen.bounds.size.height - height) / 2;
        
        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(centerX, centerY, width, height)];
        card.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
        card.layer.cornerRadius = 24;
        card.layer.borderColor = [UIColor colorWithRed:0.95 green:0.62 blue:0.04 alpha:1.0].CGColor;
        card.layer.borderWidth = 1.0;
        card.clipsToBounds = YES;
        
        UIView *headerBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 65)];
        headerBar.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
        
        UILabel *crownIcon = [[UILabel alloc] initWithFrame:CGRectMake(20, 14, 36, 36)];
        crownIcon.text = @"👑";
        crownIcon.font = [UIFont systemFontOfSize:24];
        crownIcon.textAlignment = NSTextAlignmentCenter;
        [headerBar addSubview:crownIcon];
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(64, 16, 180, 20)];
        titleLabel.text = @"MY GOLD";
        titleLabel.font = [UIFont boldSystemFontOfSize:20];
        titleLabel.textColor = [UIColor colorWithRed:0.95 green:0.62 blue:0.04 alpha:1.0];
        [headerBar addSubview:titleLabel];
        
        UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(64, 38, 180, 14)];
        subtitleLabel.text = @"License Key Verification";
        subtitleLabel.font = [UIFont systemFontOfSize:9];
        subtitleLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
        [headerBar addSubview:subtitleLabel];
        
        [card addSubview:headerBar];
        
        CGFloat startY = 80;
        CGFloat fieldWidth = width - 40;
        CGFloat fieldX = 20;
        
        UILabel *keyLabel = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, startY, fieldWidth, 12)];
        keyLabel.text = @"CHAVE DE LICENÇA";
        keyLabel.font = [UIFont boldSystemFontOfSize:8];
        keyLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
        [card addSubview:keyLabel];
        
        UITextField *keyField = [[UITextField alloc] initWithFrame:CGRectMake(fieldX, startY + 16, fieldWidth, 46)];
        keyField.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:1.0];
        keyField.layer.cornerRadius = 12;
        keyField.layer.borderColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0].CGColor;
        keyField.layer.borderWidth = 1.0;
        keyField.font = [UIFont systemFontOfSize:14];
        keyField.textColor = [UIColor whiteColor];
        keyField.placeholder = @"Insira sua chave aqui...";
        keyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        keyField.autocorrectionType = UITextAutocorrectionTypeNo;
        keyField.returnKeyType = UIReturnKeyDone;
        keyField.clearButtonMode = UITextFieldViewModeWhileEditing;
        
        UILabel *contactLabel = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, startY + 76, fieldWidth, 12)];
        contactLabel.text = @"PRECISA DE AJUDA?";
        contactLabel.font = [UIFont boldSystemFontOfSize:8];
        contactLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.4 alpha:1.0];
        contactLabel.textAlignment = NSTextAlignmentCenter;
        [card addSubview:contactLabel];
        
        UILabel *infoText = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, startY + 92, fieldWidth, 14)];
        infoText.text = @"Entre em contato com o desenvolvedor";
        infoText.font = [UIFont systemFontOfSize:10];
        infoText.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
        infoText.textAlignment = NSTextAlignmentCenter;
        [card addSubview:infoText];
        
        UIButton *contactBtn = [[UIButton alloc] initWithFrame:CGRectMake(fieldX, startY + 114, fieldWidth, 36)];
        contactBtn.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
        contactBtn.layer.cornerRadius = 10;
        contactBtn.layer.borderColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0].CGColor;
        contactBtn.layer.borderWidth = 1.0;
        
        UILabel *contactBtnLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, fieldWidth, 36)];
        contactBtnLabel.text = @"✉️  Contact Developer";
        contactBtnLabel.font = [UIFont boldSystemFontOfSize:12];
        contactBtnLabel.textColor = [UIColor colorWithRed:0.7 green:0.7 blue:0.7 alpha:1.0];
        contactBtnLabel.textAlignment = NSTextAlignmentCenter;
        [contactBtn addSubview:contactBtnLabel];
        
        [contactBtn addTarget:self action:@selector(handleContactButton) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:contactBtn];
        
        UIButton *enterBtn = [[UIButton alloc] initWithFrame:CGRectMake(fieldX, startY + 160, fieldWidth, 50)];
        enterBtn.backgroundColor = [UIColor colorWithRed:0.95 green:0.62 blue:0.04 alpha:1.0];
        enterBtn.layer.cornerRadius = 14;
        
        UILabel *enterBtnLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, fieldWidth, 50)];
        enterBtnLabel.text = @"ENTRAR";
        enterBtnLabel.font = [UIFont boldSystemFontOfSize:14];
        enterBtnLabel.textColor = [UIColor blackColor];
        enterBtnLabel.textAlignment = NSTextAlignmentCenter;
        [enterBtn addSubview:enterBtnLabel];
        
        [enterBtn addTarget:self action:@selector(handleEnterButtonWithField:) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:enterBtn];
        
        UILabel *errorLabel = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, startY + 220, fieldWidth, 30)];
        errorLabel.font = [UIFont systemFontOfSize:11];
        errorLabel.textColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.3 alpha:1.0];
        errorLabel.textAlignment = NSTextAlignmentCenter;
        errorLabel.numberOfLines = 2;
        errorLabel.hidden = YES;
        [card addSubview:errorLabel];
        
        UILabel *devTag = [[UILabel alloc] initWithFrame:CGRectMake(fieldX, height - 30, fieldWidth, 14)];
        devTag.text = @"dev: snowzdev";
        devTag.font = [UIFont boldSystemFontOfSize:8];
        devTag.textColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
        devTag.textAlignment = NSTextAlignmentCenter;
        [card addSubview:devTag];
        
        keyField.tag = 100;
        enterBtn.tag = 101;
        errorLabel.tag = 102;
        
        [card addSubview:keyField];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(preventDismiss)];
        [overlay addGestureRecognizer:tap];
        
        [overlay addSubview:card];
        window.rootViewController = [[UIViewController alloc] init];
        [window.rootViewController.view addSubview:overlay];
        [window makeKeyAndVisible];
        
        [keyField becomeFirstResponder];
    });
}

- (void)preventDismiss {
}

- (void)handleContactButton {
    NSString *contactURL = @"https://t.me/snowzdev";
    if (@available(iOS 10.0, *)) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:contactURL] options:@{} completionHandler:nil];
    }
}

- (void)handleEnterButtonWithField:(UIButton *)sender {
    UIView *field = [sender.superview viewWithTag:100];
    UILabel *errorLabel = (UILabel *)[sender.superview viewWithTag:102];
    
    if ([field isKindOfClass:[UITextField class]]) {
        UITextField *textField = (UITextField *)field;
        NSString *key = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (!key || key.length == 0) {
            errorLabel.hidden = NO;
            errorLabel.text = @"Por favor, insira uma chave válida";
            return;
        }
        
        errorLabel.hidden = NO;
        errorLabel.text = @"Verificando chave...";
        errorLabel.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.0 alpha:1.0];
        
        [self doLoginWithKey:key completion:^(BOOL success, NSString *message) {
            if (success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self->_overlayWindow) {
                        [self->_overlayWindow removeFromSuperview];
                        self->_overlayWindow = nil;
                    }
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    errorLabel.hidden = NO;
                    errorLabel.text = [NSString stringWithFormat:@"Erro: %@", message ?: @"Chave inválida ou expirada"];
                    errorLabel.textColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.3 alpha:1.0];
                    
                    UIView *card = sender.superview;
                    CABasicAnimation *shake = [CABasicAnimation animationWithKeyPath:@"position.x"];
                    shake.fromValue = @(-10);
                    shake.toValue = @(10);
                    shake.duration = 0.06;
                    shake.autoreverses = YES;
                    shake.repeatCount = 3;
                    [card.layer addAnimation:shake forKey:@"shake"];
                });
            }
        }];
    }
}

- (void)doLoginWithKey:(NSString *)key completion:(void (^)(BOOL success, NSString *message))completion {
    NSString *apiUrl = kMyGoldAPIUrl;
    NSString *packageId = kMyGoldPackageID;
    NSString *packageToken = kMyGoldPackageToken;
    
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString *hwid = [self getHWID];
    
    NSDictionary *jsonDict = @{
        @"key": key,
        @"hwid": hwid,
        @"device_model": deviceModel
    };
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&error];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:apiUrl]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:packageId forHTTPHeaderField:@"X-Package-ID"];
    [request setValue:packageToken forHTTPHeaderField:@"X-Package-Token"];
    [request setHTTPBody:jsonData];
    [request setTimeoutInterval:15.0];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, error.localizedDescription);
            });
            return;
        }
        
        NSError *jsonError;
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        if (responseDict && [responseDict[@"success"] boolValue]) {
            self.keyName = responseDict[@"name"] ?: @"Desconhecido";
            self.keyVersion = responseDict[@"version"] ?: @"1.0";
            self.keyExpiry = [NSString stringWithFormat:@"%@", responseDict[@"days_left"] ?: @"0"];
            NSString *packager = responseDict[@"packager"];
            self.packagerStatus = (packager && packager.length > 0) ? [packager uppercaseString] : @"ONLINE";
            
            [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"saved_license_key"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            _isAuthorized = YES;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES, nil);
            });
        } else {
            NSString *errorMessage = responseDict[@"error"] ?: @"Erro desconhecido";
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, errorMessage);
            });
        }
    }];
    [task resume];
}

- (void)forcePopupVisibility {
    if (!_isAuthorized) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self->_overlayWindow || self->_overlayWindow.hidden) {
                [self showLoginPopup];
            }
        });
    }
}

@end
