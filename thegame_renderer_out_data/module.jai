/*TODO What should this module be called for the data that can be used externally?
 TODO this should only contain rendering data and calls that are accessible to outside
 right now it contains everything except for the actual rendering code with Simp since
 it is simpler and more flexible until the renderer is finalized
*/

#import "thegame_math";
#import "thegame_common_data";
#import "Basic";
/*TODO We only have this because of DynamicFont so lets move that into RendererData
  and then try to have a separate renderer with a file that is just for pushing RenderEntry
  and also maybe some transformations so it can be used in dlls
  then also cleanup renderer with new method or can leave for now or also just put in dead_code
  since it never works with a dll even as a module

  ***This is more about separating out the data than anything else so that the external dll
  can have access to font information and other rendering data without having to import Simp.***
*/
#import "Simp";

#load "thegame_renderer_data.jai";
#load "thegame_render_group.jai";
