#import "AXFileViewController.h"
#import "AXFile.h"
#import "ViewController.h"

@interface AXFileViewController()

@property(nonatomic) NSMutableArray<AXFile*>* files;

@end


@implementation AXFileViewController

-(id)initWithPath:(NSString*)path{
    
    self = [super init];
    
    if(![path hasSuffix:@"/"]){
        
        self.currentPath = [path stringByAppendingString:@"/"];
        
    }else{
        
        self.currentPath = path;
        
    }
    
    self.files = [[FileManager getAXFileList:self.currentPath] mutableCopy];
    
    [self sortFiles];
    
    UIBarButtonItem* addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(createFile)];
    
    UIAction* copyAction = [UIAction actionWithTitle:@"Copy" image:nil identifier:nil handler:^(UIAction* action){NSLog(@"[Copy]%@", action);}];
    UIBarButtonItem* menu = [[UIBarButtonItem alloc] initWithTitle:@"Edit" menu:[UIMenu menuWithTitle:@"" children:@[copyAction]]];
    
    //[self setToolbarItems:@[addButton, menu]];
    
    return self;
    
}

-(void)sortFiles{
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"self.name" ascending:YES selector:@selector(caseInsensitiveCompare:)];
    NSSortDescriptor *sortDescriptor2 = [[NSSortDescriptor alloc] initWithKey:@"self.isDirectory" ascending:NO];

    self.files = [[self.files sortedArrayUsingDescriptors: @[sortDescriptor2, sortDescriptor]] mutableCopy];
    
}

-(void)viewDidLoad{
    
    //UIBarButtonItem* addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(createFile)];
    self.navigationItem.rightBarButtonItem = [self editButtonItem];
    self.tableView.allowsMultipleSelectionDuringEditing = YES;
    
}
                                  

-(void)createFile{
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Create New ..." message:@"enter file name" preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
        
        //NSLog(@"push File");
        
    }]];
    
    
    //__weak __typeof(self) wself = self;
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        
        textField.delegate = self;
        
    }];
    
    [self presentViewController:alert animated:YES completion:nil];
    
    
}

//create new file
-(void)textFieldDidEndEditing:(UITextField *)textField{
    
    NSString* name = textField.text;
    [FileManager createDirectory:[self.currentPath stringByAppendingFormat:@"%@", name]];
    AXFile* newFile = [[AXFile alloc] initWithPath:[self.currentPath stringByAppendingFormat:@"%@", name]];
    [self.files addObject:newFile];
    [self sortFiles];
    [self.tableView reloadData];
    
}

-(UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    if(self.tableView.isEditing){
        return UITableViewCellEditingStyleDelete;
    }
    
    return UITableViewCellEditingStyleNone;
    
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"削除しますか？" message:self.files[indexPath.row].name preferredStyle:UIAlertControllerStyleAlert];
        
        __weak __typeof(self) wself = self;
        
        UIAlertAction* okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            
            NSString* path = [self.currentPath stringByAppendingString:self.files[indexPath.row].name];
            [FileManager removeFile:path];
            
            [wself.files removeObjectAtIndex:indexPath.row];
            [wself.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
            [wself.tableView reloadData];
            
        }];
        
        UIAlertAction* cancelButton = [UIAlertAction actionWithTitle:@"キャンセル" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action){
            
        }];
        
        [alert addAction:cancelButton];
        [alert addAction:okButton];
        
        [self presentViewController:alert animated:YES completion:nil];
        
        
    }
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    
    return 1;
    
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    
    return self.currentPath;
    
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    return self.files.count;
    
}



-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    NSString* path = [NSString stringWithFormat:@"%@%@", self.currentPath, self.files[indexPath.row].name];
    NSLog(@"%@", path);
    
    if([FileManager isDirectory:path] && !self.tableView.isEditing){
        
        AXFileViewController* a = [[AXFileViewController alloc] initWithPath:path];
        a.title = self.files[indexPath.row].name;
        [self.navigationController pushViewController:a animated:YES];
        
    }
    
}



-(UITableViewCell*)tableView: (UITableView*)tableView cellForRowAtIndexPath: (NSIndexPath*)indexPath
{
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AXFVCell"];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"AXFVCell"];
    }
    
    cell.textLabel.text = self.files[indexPath.row].name;
    
    if(self.files[indexPath.row].isDirectory){
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.text = [@"\U0001F4C1" stringByAppendingString:cell.textLabel.text];
        
    }else{
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.text = [@"\U0001F4C4" stringByAppendingString:cell.textLabel.text];
        
    }
    
    
    return cell;
}

#ifdef DEBUG
-(void)dealloc{
    
    NSLog(@"AXFileViewController dealloc");
    
}
#endif
@end
