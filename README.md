rdhttp
======

## Deprecatopn Notice 

The library is based on NSURLConnection which is deprecated since iOS 9. 

Possibly it will be updated to use NSURLSession in the future, however taking advantage of background NSURLSession features will require significant changes to library API.

Besides deprecated networking code this library contains following valuable pieces for curious code readers:

* RDHTTPCookiesStorage — custom implementation of cookie storage 
* RDHTTPMultipartPostStream — stream that produces multipart/form-data

The code of library is non-ARC.


## Abstract


RDHTTP is HTTP client library for iOS. It is based on Apple's NSURLConnection but much easier to use and  ready for real world tasks. 

The library was designed as a simple, self-contained solution (just RDHTTP.h and RDHTTP.m). 
It is reasonably low-level and does not contain any features unrelated to HTTP (JSON, XML, SOAP, ...).

The API is inspired by now unsupported ASIHTTPRequest with few conceptual changes: blocks instead of delegates/selectors, request/operation/response separation, complete absense of synchronous calls.


## Features

* Blocks-oriented asynchronous API
* Easy access to HTTP request / response fields 
* HTTP errors detection
* Downloading data to memory or file 
* HTTP POST for key-value data (urlencoded)
* HTTP POST for files (multipart)
* Setting request body to data / file (HTTP PUT, PROPFIND, ...)
* All kinds of HTTP authorization (Basic, Digest, ...)
* Trust-callback for self-signed SSL certificates


## Requirements 

* iOS 5+ 


## Installation 

Everything in the library is contained in just two files — RDHTTP.h and RDHTTP.m; You might need to updated build-settings to secify that these files do not use ARC.

Besides that you will need to add system MobileCoreServices.framework to your project.


## Documentation 

RDHTTP documentation is written as appledoc comments in RDHTTP.h file.



## Usage Example

Simple HTTP GET:

```objective-c
RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"http://osric.readdle.com/tests/ok.html"];
[request startWithCompletionHandler:^(RDHTTPResponse *response) {
    if (response.error)
        NSLog(@"error: %@", response.error) 
    else
		NSLog(@"response text: %@", response.responseString);
}];
```

Form-data compatible HTTP POST:

```objective-c
RDHTTPRequest *request = [RDHTTPRequest postRequestWithURLString:@"http://osric.readdle.com/tests/post-values.php"];

[[request formPost] setPostValue:@"value" forKey:@"fieldName"];
[[request formPost] setPostValue:@"anotherValue" forKey:@"anotherField"];

[request startWithCompletionHandler:^(RDHTTPResponse *response) {
    if (response.error)
        NSLog(@"error: %@", response.error) 
    else
		NSLog(@"response text: %@", response.responseString);
        
}];
```

Saving file: 

```objective-c
RDHTTPRequest *request = [RDHTTPRequest getRequestWithURLString:@"http://www.ubuntu.com/start-download?distro=desktop&bits=32&release=latest"];

request.shouldSaveResponseToFile = YES;

[request setDownloadProgressHandler:^(float progress) {
    NSString *progressString = [NSString stringWithFormat:@"%f", progress];
    label.text = progressString;
    NSLog(@"%@", progressString);
}];
    
RDHTTPOperation *operation = [request startWithCompletionHandler:^(RDHTTPResponse *response) {

    if (response.error) {
        NSLog(@"error: %@", response.error);
        return;
    }
        
    NSURL *dest = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                          inDomains:NSUserDomainMask] objectAtIndex:0];
    
    dest = [dest URLByAppendingPathComponent:@"latest-ubuntu.iso"];
    
    [response moveResponseFileToURL:dest
        withIntermediateDirectories:NO 
                              error:nil];
    
    NSLog(@"saved file to latest-ubuntu.iso");
    
}];
```

