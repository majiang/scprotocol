module scprotocol;

import std.experimental.logger;
import std.typecons;

unittest
{
    import std.concurrency;
    auto serverThread = (&serverTailController).spawn("c2s.txt", "s2c.txt", 0);
    auto clientThread = (&clientTailController).spawn("s2c.txt", "c2s.txt", 0);
    serverThread.send(thisTid);
    clientThread.send(thisTid);
    receiveOnly!string.trace;
    receiveOnly!string.trace;
}

void serverTailController(string receive, string send, ulong size)
{
    import core.thread, core.time;
    import std.file, std.stdio, std.string;
    import std.concurrency : receiveOnly, Tid;
    Server server = new ServerRandom;
    auto owner = receiveOnly!Tid;
    File(send, "w").writeln(server.firstAction.toInterThreadString);
    size_t counter;
    while (counter < 10)
    {
        Thread.sleep(2.seconds);
        auto newSize = receive.getSize;
        tracef("%s: %d -> %d", receive, size, newSize);
        if (newSize <= size)
            continue;
        scope (exit) size = newSize;
        auto f = File(receive);
        f.seek(size);
        foreach (line; f.byLine)
            File(send, "a").writeln(line.chomp.idup.toClientAction.visit(server).toInterThreadString);
        counter += 1;
    }
    import std.concurrency : send;
    owner.send("server terminated.");
}

void clientTailController(string receive, string send, ulong size)
{
    import core.thread, core.time;
    import std.file, std.stdio, std.string;
    import std.concurrency : receiveOnly, Tid;
    Client client = new ClientFollow;
    auto owner = receiveOnly!Tid;
    Thread.sleep(1.seconds);
    size_t counter;
    while (counter < 10)
    {
        auto newSize = receive.getSize;
        tracef("%s: %d -> %d", receive, size, newSize);
        if (newSize <= size)
            continue;
        scope (exit) size = newSize;
        auto f = File(receive);
        f.seek(size);
        foreach (line; f.byLine)
            File(send, "a").writeln(line.chomp.idup.toServerAction.visit(client).toInterThreadString);
        counter += 1;
        Thread.sleep(2.seconds);
    }
    import std.concurrency : send;
    owner.send("client terminated.");
}

unittest
{
    import std.concurrency;
    auto clientThread = (&clientController).spawn;
    auto serverThread = (&serverController).spawn;
    clientThread.send(thisTid);
    serverThread.send(thisTid);
    clientThread.send(serverThread);
    serverThread.send(clientThread);
    trace(receiveOnly!string);
    trace(receiveOnly!string);
}

string toInterThreadString(ServerAction action)
{
    if (cast(ServerActionP)action) return "P";
    if (cast(ServerActionQ)action) return "Q";
    if (cast(ServerActionR)action) return "R";
    return "";
}

string toInterThreadString(ClientAction action)
{
    if (cast(ClientActionA)action) return "A";
    if (cast(ClientActionB)action) return "B";
    if (cast(ClientActionC)action) return "C";
    return "";
}

ClientAction toClientAction(string x)
{
    switch (x)
    {
        case "A": return new ClientActionImplA;
        case "B": return new ClientActionImplB;
        case "C": return new ClientActionImplC;
        default: return null;
    }
}

ServerAction toServerAction(string x)
{
    switch (x)
    {
        case "P": return new ServerActionImplP;
        case "Q": return new ServerActionImplQ;
        case "R": return new ServerActionImplR;
        default: return null;
    }
}

void serverController()
{
    import std.concurrency;
    auto owner = receiveOnly!Tid;
    auto clientController = receiveOnly!Tid;
    Server server = new ServerRandom;
    auto action = server.firstAction;
    foreach (i; 0..10)
    {
        clientController.send(action.toInterThreadString);
        action = receiveOnly!string.toClientAction.visit(server);
    }
    owner.send("Server terminated.");
}

void clientController()
{
    import std.concurrency;
    auto owner = receiveOnly!Tid;
    auto serverController = receiveOnly!Tid;
    Client client = new ClientFollow;
    foreach (i; 0..10)
    {
        serverController.send(receiveOnly!string.toServerAction.visit(client).toInterThreadString);
    }
    owner.send("Client terminated.");
}

unittest
{
    Client client = new ClientFollow;
    Server server = new ServerRandom;
    ServerAction serverAction = server.firstAction;
    foreach (i; 0..10)
    {
        ClientAction clientAction = serverAction.visit(client);
        serverAction = clientAction.visit(server);
    }
}

I classselect(alias I, A, B)()
{
    import std.random;
    if (uniform01 < 0.5)
        return new A;
    return new B;
}
class ServerRandom : Server
{
    ServerAction firstAction(){return new ServerActionImplP;}
    ServerReactionA accept(ClientActionA action){
        return classselect!(ServerReactionA, ServerActionImplQ, ServerActionImplR);}
    ServerReactionB accept(ClientActionB action){
        return classselect!(ServerReactionB, ServerActionImplP, ServerActionImplR);}
    ServerReactionC accept(ClientActionC action){
        return classselect!(ServerReactionC, ServerActionImplP, ServerActionImplQ);}
}
class ClientFollow : Client
{
    ClientReactionP accept(ServerActionP action){return new ClientActionImplB;}
    ClientReactionQ accept(ServerActionQ action){return new ClientActionImplC;}
    ClientReactionR accept(ServerActionR action){return new ClientActionImplA;}
}

interface Server
{
    ServerAction firstAction(); /// Called by controller.
    ServerReactionA accept(ClientActionA action); /// called by ClientActionA.
    ServerReactionB accept(ClientActionB action); /// ditto
    ServerReactionC accept(ClientActionC action); /// ditto
}
interface Client
{
    ClientReactionP accept(ServerActionP action);
    ClientReactionQ accept(ServerActionQ action);
    ClientReactionR accept(ServerActionR action);
}

interface ServerAction
{
    ClientAction visit(Client client);
}
interface ServerReactionA : ServerAction{}
interface ServerReactionB : ServerAction{}
interface ServerReactionC : ServerAction{}
interface ServerActionP : ServerReactionB, ServerReactionC{}
interface ServerActionQ : ServerReactionA, ServerReactionC{}
interface ServerActionR : ServerReactionA, ServerReactionB{}
class ServerActionImplP : ServerActionP{ClientAction visit(Client client){trace("P");return client.accept(this);}}
class ServerActionImplQ : ServerActionQ{ClientAction visit(Client client){trace("Q");return client.accept(this);}}
class ServerActionImplR : ServerActionR{ClientAction visit(Client client){trace("R");return client.accept(this);}}

interface ClientAction
{
    ServerAction visit(Server server);
}

interface ClientReactionP : ClientAction{}
interface ClientReactionQ : ClientAction{}
interface ClientReactionR : ClientAction{}
interface ClientActionA : ClientReactionQ, ClientReactionR{}
interface ClientActionB : ClientReactionP, ClientReactionR{}
interface ClientActionC : ClientReactionP, ClientReactionQ{}
class ClientActionImplA : ClientActionA{ServerAction visit(Server server){trace("A");return server.accept(this);}}
class ClientActionImplB : ClientActionB{ServerAction visit(Server server){trace("B");return server.accept(this);}}
class ClientActionImplC : ClientActionC{ServerAction visit(Server server){trace("C");return server.accept(this);}}
