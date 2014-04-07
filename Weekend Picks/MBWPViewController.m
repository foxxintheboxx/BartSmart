//
//  MBWPViewController.m
//  Weekend Picks
//
//  Modified by Ian Fox 5/6/2014
//  Copyright (c) 2012 MapBox / Development Seed. All rights reserved.
//

#import "MBWPViewController.h"

#import "MBWPSearchViewController.h"
#import "MBWPDetailViewController.h"

#import "UIColor+MBWPExtensions.h"

#define kNormalMapID  @"foxxintheboxx.hneeig66"
#define kRetinaMapID  @"foxxintheboxx.hneeig66"
#define kTintColorHex @"#AA0000"

@interface MBWPViewController () <UISearchBarDelegate>
@property  (strong) NSMutableDictionary *annotations;
@property (strong) IBOutlet RMMapView *mapView;
@property  (strong) NSMutableDictionary *markers;
@property (strong) NSArray *activeFilterTypes;

@property (strong, nonatomic) IBOutlet UISearchBar *search;

@end

#pragma mark -

@implementation MBWPViewController
@synthesize markers;
@synthesize annotations;
@synthesize mapView;
@synthesize activeFilterTypes;

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.search.showsCancelButton = YES;
    [self.search setShowsScopeBar: YES];
    self.search.delegate = self;
    
    self.annotations = [[NSMutableDictionary alloc] init];
    self.markers = [[NSMutableDictionary alloc] init];
    self.mapView.tileSource = [[RMMapBoxSource alloc] initWithMapID:([[UIScreen mainScreen] scale] > 1.0 ? kRetinaMapID : kNormalMapID)
                                              enablingDataOnMapView:self.mapView];
    
    self.mapView.zoom = 2;
    
    [self.mapView setConstraintsSouthWest:[self.mapView.tileSource latitudeLongitudeBoundingBox].southWest
                                northEast:[self.mapView.tileSource latitudeLongitudeBoundingBox].northEast];
    
    self.mapView.showsUserLocation = YES;
    
    self.title = [self.mapView.tileSource shortName];
    
    // zoom in to markers after launch
    //
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
    //[self.mapView addGestureRecognizer:gestureRecognizer];
    __weak RMMapView *weakMap = self.mapView; // avoid block-based memory leak
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^(void)
                   {
                       float degreeRadius = 0.5; // (9000m / 110km per degree latitude)
                       
                       CLLocationCoordinate2D centerCoordinate = [((RMMapBoxSource *)self.mapView.tileSource) centerCoordinate];
                       
                       RMSphericalTrapezium zoomBounds = {
                           .southWest = {
                               .latitude  = centerCoordinate.latitude  - degreeRadius,
                               .longitude = centerCoordinate.longitude - degreeRadius
                           },
                           .northEast = {
                               .latitude  = centerCoordinate.latitude  + degreeRadius,
                               .longitude = centerCoordinate.longitude + degreeRadius
                           }
                       };
                       
                       [weakMap zoomWithLatitudeLongitudeBoundsSouthWest:zoomBounds.southWest
                                                               northEast:zoomBounds.northEast
                                                                animated:YES];
                   });
}

//#pragma mark -
//
- (void)presentSearch:(id)sender
{
    NSMutableArray *filterTypes = [NSMutableArray array];

    for (RMAnnotation *annotation in self.mapView.annotations)
    {
        if (annotation.userInfo && [annotation.userInfo objectForKey:@"marker-symbol"] && ! [[filterTypes valueForKeyPath:@"marker-symbol"] containsObject:[annotation.userInfo objectForKey:@"marker-symbol"]])
        {
            BOOL selected = ( ! self.activeFilterTypes || [self.activeFilterTypes containsObject:[annotation.userInfo objectForKey:@"marker-symbol"]]);

            [filterTypes addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       [annotation.userInfo objectForKey:@"marker-symbol"], @"marker-symbol",
                                       [UIImage imageWithCGImage:(CGImageRef)[self mapView:self.mapView layerForAnnotation:annotation].contents], @"image",
                                       [NSNumber numberWithBool:selected], @"selected",
                                       nil]];
        }
    }

    MBWPSearchViewController *searchController = [[MBWPSearchViewController alloc] initWithNibName:nil bundle:nil];

    searchController.delegate = self;
    searchController.filterTypes = [NSArray arrayWithArray:filterTypes];

    UINavigationController *wrapper = [[UINavigationController alloc] initWithRootViewController:searchController];

    wrapper.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
    wrapper.topViewController.title = @"Search";

    [self presentModalViewController:wrapper animated:YES];
}
//
//#pragma mark -
//
- (RMMapLayer *)mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation
{
    if (annotation.isUserLocationAnnotation)
        return nil;
    RMMarker *marker;
    if (annotation.userInfo != NULL)
    {
        marker = [[RMMarker alloc] initWithMapBoxMarkerImage:[annotation.userInfo objectForKey:@"marker-symbol"]
                                                tintColorHex:[annotation.userInfo objectForKey:@"marker-color"]
                                                  sizeString:[annotation.userInfo objectForKey:@"marker-size"]];
    }
    else
    {
        marker = [[RMMarker alloc] initWithMapBoxMarkerImage:@"bus" tintColorHex:@"bf3f3f" sizeString:@"small"];
    }
    
    marker.canShowCallout = YES;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    marker.rightCalloutAccessoryView = button;
    button.frame = CGRectMake(10.0, 140.0, 100.0, 10.0);
    if (annotation.userInfo != NULL)
    {
        [button setTitle:@"Report Late" forState:UIControlStateNormal];
    } else {
        [button setTitle:@"On Time" forState:UIControlStateNormal];
    }
    //if (self.activeFilterTypes)
    //  marker.hidden = ! [self.activeFilterTypes containsObject:[annotation.userInfo objectForKey:@"marker-symbol"]];
    NSLog(@"BACK");
    if (annotation.userInfo != NULL && [self.annotations valueForKey:[annotation.userInfo  objectForKey:@"title"]]== NULL) {
        [self.annotations setValue:annotation forKey: [annotation.userInfo objectForKey:@"title"]];
    }
    [self.markers setValue:annotation forKey: annotation.title];
    return marker;
}
//
- (void)tapOnCalloutAccessoryControl:(UIControl *)control forAnnotation:(RMAnnotation *)annotation onMap:(RMMapView *)map
{
    [self.view endEditing:YES];
    NSLog(@"%@", annotation.userInfo);
    [self.mapView removeAnnotation: annotation];
    RMMarker *marker = [[RMMarker alloc] initWithMapBoxMarkerImage:[annotation.userInfo objectForKey:@"marker-symbol"]
                                                      tintColorHex:[annotation.userInfo objectForKey:@"#bf3f3f"]
                                                        sizeString:[annotation.userInfo objectForKey:@"marker-size"]];
    //NSLog(@"Delete");
    if (annotation.userInfo == NULL)
    {
        annotation = [self.annotations valueForKey:annotation.title];
    }
    else
    {
        annotation = [RMAnnotation annotationWithMapView: self.mapView coordinate: annotation.coordinate andTitle: annotation.title];
    }
    //NSLog(@"%@", annotation.userInfo);
    [self.mapView addAnnotation: annotation];
}
- (void)hideKeyboard
{

    [self.view endEditing:YES];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    if ([self.markers valueForKey: searchText] != NULL) {
        NSArray *places =  self.markers.allValues;
        for (int i = 0; i < places.count; i++) {
            RMAnnotation *place = [places objectAtIndex:i];
            if (![place.title isEqualToString:searchText]) {
                NSLog(@"%@", place.title);
                [self.mapView removeAnnotation: place];
            }
        }        NSLog(@"here");
    }
    if ([searchText isEqualToString:@""]) {
        [self.mapView removeAllAnnotations];
        NSArray *places =  self.markers.allValues;
        for (int i = 0; i < places.count; i++) {
            RMAnnotation *place = [places objectAtIndex:i];
            [self.mapView addAnnotation: place];

        }
        
    }
    
}
-(void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self.view endEditing:YES];
}


@end
