# xLib6000
## Mac implementation of the FlexRadio (TM) series 6000 software defined radios API (FlexLib)

Builds on macOS 10.13.3 using XCode 9.2 (9c40b) using Swift 4 with a Deployment
Target of macOS 10.10



** NOTE **: Version 0.9.1328 is a major reorganization of this framework. Most of the
functionality is unchanged but a new class has been added (Api.swift) and the initialization of the
framework has been changed to start with an Api object (not a Radio object).


==========================================================================

This framework provides most of the capability of FlexLib but does not 
provide an identical interface due to the differences between the Windows
and macOS environments and system services.

CocoaAsyncSocket is embedded in this project as source code
(version 7.6.1 as of 2017-06-24
see https://github.com/robbiehanson/CocoaAsyncSocket)


==========================================================================

Comments and/or questions to:    douglas.adams@me.com

==========================================================================

Once compiled, the framework should be placed in a folder on your Mac where
frameworks can be referenced (typically ~/Library/Frameworks)

A compiled DEBUG build framework is contained in the GitHub Release if
you would rather not build from sources.

If you require a RELEASE build you will have to build from sources.
