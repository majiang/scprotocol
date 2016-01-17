module scprotocol;

import std.experimental.logger;
import std.typecons;

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
