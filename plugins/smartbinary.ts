import { PlugIn } from '../interfaces/plugin'

// This class name is used in the device configuration and UX
export class smartbinary implements PlugIn {

    // Sample code
    private devices = {};
    private deviceState = new Map();

    // this is used by the UX to show some information about the plugin
    public usage: string = "This is a sample plugin that will provide an integer that decrements by 1 on every loop or manual send. Acts on the device for all capabilities"

    // this is called when mock-devices first starts. time hear adds to start up time
    public initialize = () => {
        
        return undefined;
    }

    // not implemented
    public reset = () => {
        return undefined;
    }

    // this is called when a device is added or it's configuration has changed i.e. one of the capabilities has changed
    public configureDevice = (deviceId: string, running: boolean) => {
        if (!running) {
            this.devices[deviceId] = {};
        }
        if(!this.deviceState.has(deviceId))
        {
            this.deviceState.set(deviceId,
                {
                    state: false
                });
        }
    }

    // this is called when a device has gone through dps/hub connection cycles and is ready to send data
    public postConnect = (deviceId: string) => {
        return undefined;
    }

    // this is called when a device has fully stopped sending data
    public stopDevice = (deviceId: string) => {
        return undefined;
    }

    // this is called during the loop cycle for a given capability or if Send is pressed in UX
    public propertyResponse = (deviceId: string, capability: any, payload: any) => {
        // if (Object.getOwnPropertyNames(this.devices[deviceId]).indexOf(capability._id) > -1) {
        //     this.devices[deviceId][capability._id] = this.devices[deviceId][capability._id] - 1;
        //     this.devices[deviceId][capability._id]
        // } else {

//        var temp = 0;
        var value = JSON.parse(payload);
            //  I really technically don't need to save presence state for this simple algorith
            // but leaving it here since it's already written and we may change the algoright        
        var devState = this.deviceState.get(deviceId);
        var currState = devState.state;

        var percentOn=value.percentOn;

        var presenceOdds = Math.random() * 100;
        if(presenceOdds <= percentOn)
        currState=true;
        else
        currState=false;

        this.devices[deviceId][capability._id] = currState;
            //this.currentTemp = temp;

//        this.devices[deviceId][capability._id] = (Math.random() * 100);
        this.deviceState.set(deviceId,
        {
            present: currState
        });
            
        // }
        return this.devices[deviceId][capability._id];
    }

    // this is called when the device is sent a C2D Command or Direct Method
    public commandResponse = (deviceId: string, capability: any) => {
        return undefined;
    }

    // this is called when the device is sent a desired twin property
    public desiredResponse = (deviceId: string, capability: any) => {
        return undefined;
    }
}
