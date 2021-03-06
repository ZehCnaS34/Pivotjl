using URIParser, MbedTLS, WebSockets

"""
# Engine
"""
type Engine
    router::Router
end

# right now, I'll just use the default Mux
Engine()=Engine(Pivot.TRouter())

handle!(fn::Handler,
        e::Engine,
        method::Verb,
        path::AbstractString) = handle!(fn, e.router, method, parseurl(path))

handle!(e::Engine,
        fn::Handler,
        method::Verb,
        path::AbstractString) = handle!(fn, e.router, method, parseurl(path))

use!(e::Engine, fn::Function) = use!(e.router, fn)
use!(fn::Function, e::Engine) = use!(e.router, fn)
use!(e::Engine, fns::Function...) = map((fn) -> use!(e, fn), fns)


"""
# buildhandler

returns a function that is considered the app of mux middleware.

This function fetched the proper endpoint, along with the proper handler, then passes the context through the middleware
"""
function buildhandler(router::Router)
    function (ctx)
        ep, params = fetch(router, ctx.data[:request][:path])
        method = STI[ctx.data[:request][:method]]
        ctx.data[:params] = params
        ctx |> proper_method(method, ep.handlermap)
    end
end


"""
# run

runs the server
"""
function run(e::Engine, port::Number=8080; keyspath="", reference=Dict())
    Pivot.finalize!(e.router)
    reference[:http] = HttpHandler() do req::Request, res::Response
        # need to parse the path
        rq = req |> Mux.todict |> Pivot.splitquery
        ctx = Context(req)
        ctx.data[:router] = e.router
        ctx.data[:request] = rq
        ctx.data[:reference] = reference
        str_resp = mux(e.router.middleware, buildhandler(e.router))(ctx)
        ctx.response.data = convert(Vector{UInt8}, str_resp)
        Response(ctx)
    end

    reference[:socket] = WebSocketHandler() do req, client
        while true
            msg = read(client) |> utf8
            write(client, msg)
        end
    end

    reference[:server] = Server(reference[:http],
                                reference[:socket])

    # ssl for https
    # TODO: test remotely
    if keyspath != ""
        rel = create_rp(keyspath)
        generate_ssl(rel(""))

        cert = MbedTLS.crt_parse_file(rel("keys/server.crt"))
        key = MbedTLS.parse_keyfile(rel("keys/server.key"))
        HttpServer.run(reference[:server], port=port, ssl=(cert, key))
        return
    end

    HttpServer.run(reference[:server], port)
end
