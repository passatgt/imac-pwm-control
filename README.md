# iMac PWM Control

## Background
This small toolbar app was originally created to fix brightness control issues on 2010 and 2011 iMacs with replaced MXM graphics card(like 765M, 770M and 780M). With these cards, your iMac's screen always runs and max brightness(backlight). With this app, you can simulate the backlight change by changing the screen's gamma values, so every content on the screen will get darker as you decrease brightness. This still runs your backlight at max though. The second option is to use Node-RED on a Raspberry PI with the following blueprint:

```
[{"id":"4e1b56ef.50b3c","type":"tab","label":"Flow 1","disabled":false,"info":""},{"id":"35a40d00.56a73c","type":"http response","z":"4e1b56ef.50b3c","name":"","statusCode":"","headers":{},"x":1010,"y":680,"wires":[]},{"id":"4e55ec6b.b87534","type":"template","z":"4e1b56ef.50b3c","name":"page","field":"payload","fieldType":"msg","format":"handlebars","syntax":"mustache","template":"<html>\n    <head></head>\n    <body>\n        <h1>PWM set to {{req.params.brightness}}!</h1>\n    </body>\n</html>","output":"str","x":810,"y":700,"wires":[["35a40d00.56a73c"]]},{"id":"8ae82c17.a019a","type":"http in","z":"4e1b56ef.50b3c","name":"PWM endpoint","url":"/pwm/:brightness","method":"get","upload":false,"swaggerDoc":"","x":600,"y":440,"wires":[["4e55ec6b.b87534","f8c687f1.74b198"]]},{"id":"ce3249eb.f6b3d8","type":"rpi-gpio out","z":"4e1b56ef.50b3c","name":"","pin":"40","set":"","level":"0","freq":"1000","out":"pwm","x":1310,"y":440,"wires":[]},{"id":"f8c687f1.74b198","type":"function","z":"4e1b56ef.50b3c","name":"","func":"return {'payload':msg.req.params.brightness};","outputs":1,"noerr":0,"x":890,"y":280,"wires":[["ce3249eb.f6b3d8"]]}]
```

Connect GPIO 21 from Raspberry PI to the PWM input on the LED Driver Board in your iMac(and obviously cut the original PWM cable). Enter your Node-RED address in the app settings and now you should be able to adjust the actual backlight of the screen.

## Install
You can download the app from the Releases.

## Building
You can build your own version, just run `pod install` first.

## Tips
Add the app under System settings / Users & Groups / Login items, so it will start automatically when MacOS boots up.
