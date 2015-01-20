# HTTP Responder

http://httpresponder.com/ is a web hook debugging and stubbing tool. It logs web hook requests, but unlike other tools it also allows the configuration of a default response for JSON and XML requests.

[![Travis-CI](https://travis-ci.org/aaronlerch/respond-to-it.svg?branch=master)](https://travis-ci.org/aaronlerch/respond-to-it)

## Web Hooks

Web hooks have traditionally been (and continue to be) one-way notifications over HTTP. Tools like http://httpresponder.com/ or http://requestb.in/ exist to make it easier to analyze web hook behavior when implementing a service to process the hook's request. (Think "glorified `puts` statement.")

## Web Hooks as Workflow

Increasingly, web hooks are not only used for push notifications, but can also be used in a workflow scenario: the response to a web hook request can instruct the calling server on what behavior to execute next. A good example of this is [Twilio](http://twilio.com/). An entire call flow is implemented through a series of web hooks that respond with XML defining the next set of actions to take.

# Deploy your own

If the limitations of http://httpresponder.com/ don't match your needs, you can easily deploy your own version on heroku:

    git clone git://github.com/aaronlerch/respond-to-it.git
    cd respond-to-it
    heroku create --stack cedar
    heroku addons:add redistogo:nano
    git push heroku master

Then tweak to your heart's content.

Or just push the button:

[![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)

Written by [Aaron Lerch](https://github.com/aaronlerch). For additional
contributors, who are awesome, see [CONTRIBUTORS](CONTRIBUTORS.md).
