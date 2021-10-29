import { PlugIn } from '../interfaces/plugin'

// This class name is used in the device configuration and UX
export class hvac implements PlugIn {

    // Sample code
    private devices = {};
    private deviceState = new Map();

    // this is used by the UX to show some information about the plugin
    public usage: string = "This plugin simulates a simple hvac system"

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
                    currAirFlow: 0, 
                    currTemp: 0,
                    currGoingUp: true,
                    minTempConfig: 0,
                    maxTempConfig: 100
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

        var value = JSON.parse(payload);
        var devState = this.deviceState.get(deviceId);
        var currTemp = devState.currTemp;
        var currGoingUp = devState.currGoingUp;     
        var minTempConfig = devState.minTempConfig;
        var maxTempConfig = devState.maxTempConfig;  

        if(value.type === 'temp')
        {
            var min=value.min;
            var max=value.max;
            minTempConfig = value.min;
            maxTempConfig = value.max;
            var increment = value.increment;

            //console.log('payload=' + payload + ', min= ' + value.min + ', max=' + value.max+ ', increment=' + value.increment);

            //set initial temp state to min
            if(currTemp < min)
            {
                currTemp = min;
                currGoingUp = true;
            }

            if(currGoingUp === true)
            {
                currTemp = currTemp + increment;
                if(currTemp > max)
                {
                    currTemp=max;
                    currGoingUp=false;
                }
            }
            else
            {
                currTemp = currTemp - increment;
                if(currTemp < min)
                {
                    currTemp=min;
                    currGoingUp=true;
                }
            }

            this.devices[deviceId][capability._id] = currTemp;
        }
        else if (value.type === 'airflow')
        {
            // calculate airflow as a percentage of the temperature between the min and max
            // i.e. the further the air gets away from the min-setpoint, the harder it blows on a scale of 0-100%
            // return as 'int'
            var airFlowPercent= (((currTemp - minTempConfig) / (maxTempConfig-minTempConfig)) * 100).toFixed();
            // console.log('currTemp=' + currTemp);
            // console.log('maxTempConfig=' + maxTempConfig);
            // console.log('minTempConfig=' + minTempConfig);
            // console.log('airflowPercent=' + airFlowPercent);
            this.devices[deviceId][capability._id] = airFlowPercent;
        }
        else
        {
            console.log('bad hvac data type:' + value.type);
        }

        this.deviceState.set(deviceId,
            {
                currAirFlow: airFlowPercent, 
                currTemp: currTemp,
                currGoingUp: currGoingUp,
                minTempConfig: minTempConfig,
                maxTempConfig: maxTempConfig
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
