> **Warning**
>
> A note from @aaronlerch: This project has been running for years on a free heroku app tier. The dependencies are out of date and security holes have been discovered in those dependencies over time. The entire project needs a refresh, which I won't be doing. If you are seeking to catch and analyze http traffic for webhooks, I recommend https://ngrok.com/ and running a simple local server.
>
> If anybody is still using http://httpresponder.com/ then I wish you the best and thank you for using this simple little tool!

# HTTP Responder

http://httpresponder.com/ is a web hook debugging and stubbing tool. It logs web hook requests, but unlike other tools it also allows the configuration of a default response for JSON and XML requests.

## Web Hooks

Web hooks have traditionally been (and continue to be) one-way notifications over HTTP. Tools like http://httpresponder.com/ or http://requestb.in/ exist to make it easier to analyze web hook behavior when implementing a service to process the hook's request. (Think "glorified `puts` statement.")

## Web Hooks as Workflow

Increasingly, web hooks are not only used for push notifications, but can also be used in a workflow scenario: the response to a web hook request can instruct the calling server on what behavior to execute next. A good example of this is [Twilio](http://twilio.com/). An entire call flow is implemented through a series of web hooks that respond with XML defining the next set of actions to take.

## Contributions

Written by [Aaron Lerch](https://github.com/aaronlerch). For additional
contributors, who are awesome, see [CONTRIBUTORS](CONTRIBUTORS.md).
