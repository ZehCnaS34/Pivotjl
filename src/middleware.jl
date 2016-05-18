module Security

SEED = "+_)(*&^%\$#@!+=-`~\";:/?\\><.,qwertyuiopasdfghjklzxcvbnm123456789"


function csrf(app, ctx)
  ctx[:csrf_token] = "nothing yet"
  app(ctx)
end

end


module Filter
using HttpServer
import HttpCommon: Cookie

"""
# query_todict

Converts the query from the request to a dictionary. Then stores in to locations
ctx[:request][:query] -- overwriting the raw version
ctx[:query] -- for convenience
"""
function query_todict(key_type=string)
  function (app, ctx) 
    raw_query = ctx[:request][:query]
    tda = filter(map((kv) -> split(kv, "=") ,split(raw_query, "&"))) do p
      length(p) > 1
    end
    marshalled = [ key_type(k) => v for (k,v) in tda]
    ctx[:request][:query] = marshalled
    ctx[:query] = marshalled
    app(ctx)
  end
end

function session()
  function (app, ctx)
    resp = app(ctx)

    resp = Response(resp)

    resp.cookies["session"] = Cookie("session", "asdpfiojasdpofij")

    resp
  end
end

end


module Logger
import HttpServer.mimetypes

"""
# simple
assumes that the proper engine middleware is included
"""
function simple(ap, ctx)
  s = time()
  output =  ap(ctx)
  f = time()
  println("[$(ctx[:request][:method]) $(join(ctx[:request][:path], "/") * "/")] -- $(f - s) (s)")
  output
end

end

module Static

using Mustache
export render
import HttpServer: Response, mimetypes

"""
Defines the proper variables for the template home
"""
function template(template_directory)
  function (app, ctx)
    ctx[:template_dir] = abspath(template_directory)
    app(ctx)
  end
end

function mime(s)
  if in(s, mimetypes |> keys)
    return mimetypes[s]
  end
  "text/plain"
end


"""
# public serve some static files?
"""
function public(public_directory)
  function (app, ctx)
    resourcefile = joinpath(public_directory,
      join(ctx[:request][:path], "/")) |> abspath

    if isfile(resourcefile)
      ext = split(resourcefile |> basename, ".")[end]
      f = open(resourcefile)
      res = Response(join(readlines(f), ""))
      close(f)
      res.headers["Content-Type"] = mime(ext) * "; charset=utf-8"
      return res
    end

    app(ctx)
  end
end

"""
# render

should render a file as a request

later on, I should deff cache this
"""
function render(ctx, filename, data=Dict())
  template_location = ctx[:template_dir]
  f = open(joinpath(template_location, filename))
  content = join(readlines(f), "")
  close(f)
  Mustache.render(content, data)
end

end
