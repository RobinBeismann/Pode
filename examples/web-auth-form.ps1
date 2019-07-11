$path = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Path)
Import-Module "$($path)/src/Pode.psm1" -Force -ErrorAction Stop

# or just:
# Import-Module Pode

<#
This examples shows how to use session persistant authentication, for things like logins on websites.
The example used here is Form authentication, sent from the <form> in HTML.

Navigating to the 'http://localhost:8085' endpoint in your browser will auto-rediect you to the '/login'
page. Here, you can type the username (morty) and the password (pickle); clicking 'Login' will take you
back to the home page with a greeting and a view counter. Clicking 'Logout' will purge the session and
take you back to the login page.
#>

# create a server, and start listening on port 8085
Start-PodeServer -Threads 2 {

    # listen on localhost:8085
    Add-PodeEndpoint -Address *:8085 -Protocol HTTP

    # set the view engine
    Set-PodeViewEngine -Type Pode

    # setup session details
    middleware (session @{
        'Secret' = 'schwifty';
        'Duration' = 120;
        'Extend' = $true;
    })

    # setup form auth (<form> in HTML)
    auth use login -t form -v {
        param($username, $password)

        # here you'd check a real user storage, this is just for example
        if ($username -eq 'morty' -and $password -eq 'pickle') {
            return @{ 'user' = @{
                'ID' ='M0R7Y302'
                'Name' = 'Morty';
                'Type' = 'Human';
            } }
        }

        return @{ 'message' = 'Invalid details supplied' }
    }

    # home page:
    # redirects to login page if not authenticated
    route 'get' '/' (auth check login -o @{ 'failureUrl' = '/login' }) {
        param($e)

        $e.Session.Data.Views++

        Write-PodeViewResponse -Path 'auth-home' -Data @{
            'Username' = $e.Auth.User.Name;
            'Views' = $e.Session.Data.Views;
        }
    }

    # login page:
    # the login flag set below checks if there is already an authenticated session cookie. If there is, then
    # the user is redirected to the home page. If there is no session then the login page will load without
    # checking user authetication (to prevent a 401 status)
    route 'get' '/login' (auth check login -o @{ 'login' = $true; 'successUrl' = '/' }) {
        param($e)
        Write-PodeViewResponse -Path 'auth-login' -FlashMessages
    }

    # login check:
    # this is the endpoint the <form>'s action will invoke. If the user validates then they are set against
    # the session as authenticated, and redirect to the home page. If they fail, then the login page reloads
    route 'post' '/login' (auth check login -o @{
        'failureUrl' = '/login';
        'successUrl' = '/';
        'failureFlash' = $true;
    }) {}

    # logout check:
    # when the logout button is click, this endpoint is invoked. The logout flag set below informs this call
    # to purge the currently authenticated session, and then redirect back to the login page
    route 'post' '/logout' (auth check login -o @{
        'logout' = $true;
        'failureUrl' = '/login';
    }) {}

}