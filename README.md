# VMC on AWS Sizer Script

**Please be aware that this is an unsupported script, please check all calculations before making decisions based on this output**

I put this sizer script together on order to help people who are looking to size VMware Cloud on AWS SDDC deployments. I have posted an article on this on my blog, which you can locate here: [VMC Sizing Script and the VMC Sizer API Blog Post](https://adambohle.com/post/vmc-sizing-script/)

The script accepts a number of parameters and I just wanted to documment those here in the Readme so that people are aware of those.

**-vcenterqdn** this is a mandatory parameter in order for the script to connect to the on-premise vCenter server which you want to analyse for VMs. You can supply either the FQDN or the IP Address, you will be prompted for credentials at runtime

**-instancetype** again this is a mandatory parameter and is used to specify the VMC on AWS instance type which you want to size for, either "i3" or "i3en"

There is a number of other parameters which you can pass to the script these are all detailed out in the first part of the script, and are hopefully fairly self explanatory and come with help text

```PowerShell
param (
    [Parameter(Position=0,mandatory=$true,HelpMessage="Enter the vCenter FQDN or IP address which you would like to gather sizing information from.")]
    [string] $vcenterfqdn, 
    [Parameter(Position=1,mandatory=$true,HelpMessage="Enter the VMC instance type you would like to size for, i3 or i3en")]
    [string] $instancetype,
    [Parameter(Position=2,mandatory=$false,HelpMessage="Enter the vCPU to Core Ratio you want to use, if you specify nothing then the default value will be 4")]
    [int] $vcpuspercore = 4,
    [Parameter(Position=3,mandatory=$false,HelpMessage="Enter the vRAM to Physical RAM Ratio you want to use, if you specify nothing then the default value will be 1.25")]
    [decimal] $targetramratio = 1.25,
    [Parameter(Position=4,mandatory=$false,HelpMessage="Enter the CPU Utililization, if you specify nothing the default value will be 30")]
    [int] $cpuutilization = 30,
    [Parameter(Position=5,mandatory=$false,HelpMessage="Enter the Memory Utililization, if you specify nothing the default value will be 100")]
    [int] $memoryutilization = 100)
```

The script comes if a JSON template which will be used and fed into the script when creating the JSON payload to send to the VMC sizer API. This will need to exist in the same directory as the sizing-vmc.ps1 file.

The functionality of this script is pretty straight forward. It will do the following

1. Connect to vCenter of your choosing
2. Collect all the VMDK files on the vCenter and add up the allocated storage
3. Collect all the VMs on the vCenter server and calculate the number of VMs, the vCPU allocations as well as Memory
4. It will take this information and POST this to the [VMC Sizer](https://vmc.vmware.com/sizer/workload-profiles) and return the results.

## Future Features and Functions which I would like to include at some point.

1. I would like to include the capability for the script to size for both i3 and i3en hosts in one run of the API call or loop through multipl calls and provide results quickly and efficiently
2. Include a reference to VMC Sizing. I do not believe there is an API for pricing information so I may look at putting the pricing info in a JSON file and referencing that, will need to keep that JSON up to date.
3. I would like to add a function where this script can pull info straight from a RVTools export. That might be useful to speed up sizing potentially. Need to think about this.
4. I can certainly clean up the output and format this detail a little better ;)