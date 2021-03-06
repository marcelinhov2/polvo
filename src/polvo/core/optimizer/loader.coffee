fs = require 'fs'
path = require 'path'
util = require 'util'

{log,debug,warn,error} = require '../../utils/log-util'

module.exports = class Loader

  node_modules: null

  constructor:( @polvo, @cli, @config, @tentacle, @optimizer )->
    @node_modules = path.join @polvo.polvo_base, 'node_modules'


  write_amd_loader:( paths )->

    # increment map with all remote vendors
    paths or= {}
    for name, url of @config.vendors
      paths[name] = url if /^http/m.test url

    # mounting main polvo file, contains the polvo builtin amd loader, 
    # all the necessary configs and a hash map containing the layer location
    # for each module that was merged into it.

    loader = @get_socketio()
    loader += @get_amd_loader()

    if paths?
      paths = (util.inspect paths).replace /\s/g, ''
    else paths = '{}'

    loader += """\n\n
      /*************************************************************************
       * Automatic configuration by Polvo.
      *************************************************************************/

      require.config({
        baseUrl: '#{@config.base_url}',
        paths: #{paths}
      });
      require( ['#{@config.main_module}'] );

      /*************************************************************************
       * Automatic configuration by Polvo.
      *************************************************************************/
    """

    # writing to disk
    release_path = path.join @config.destination, @config.index

    if @config.optimize.minify && @cli.r
      loader = MinifyUtil.min loader

    fs.writeFileSync release_path, loader

  get_amd_loader:->
    rjs_path = path.join @node_modules, 'requirejs', 'require.js'
    fs.readFileSync rjs_path, 'utf-8'

  get_socketio:->
    initializer = """\n\n
      /*************************************************************************
       * Socket Initializer for LiveReload by Polvo.
      *************************************************************************/

      var refresher = io.connect("http://localhost");
      refresher.on("refresh", function(data)
      {
        if(data.file_type == 'javascript')
          return location.reload();
        
        // forcing reload of style        
        require.undef( data.file_id );
        require([data.file_id]);
      });

      /*************************************************************************
       * Socket Initializer for LiveReload by Polvo.
      *************************************************************************/
    """

    io_path = path.join @node_modules, 'socket.io', 'node_modules'
    io_path = path.join io_path, 'socket.io-client', 'dist', 'socket.io.js'
    
    io = fs.readFileSync io_path, 'utf-8'
    io += "\n\n\n#{initializer}\n\n\n"
