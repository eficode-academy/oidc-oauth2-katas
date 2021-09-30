const doRequest = async (method, baseUrl, path, data) => {
    console.log('doRequest', method, baseUrl, path, data);
    let options = {
	url: baseUrl + path,
	method,
	headers: {
            'accept': 'application/json',
            'content-type': 'application/json',
        },
	timeout: 2000,
	withCredentials: true  // Include cookies
    };
    if (data) {
	options.data = data
    }
    try {
	const response = await axios.request(options);
	console.log('Response data', response.data);
	if (response.data) {
	    return response.data;
	}
	return null;
    } catch (error) {
	console.log('Error', error);
	return null;
    }
}

const doBFFRequest = async (method, path, data) => {
    let configuration = JSON.parse(localStorage.getItem('configuration'));
    return doRequest(method, configuration.loginBaseUrl, path, data);
}

const doAPIRequest = async (method, path, data) => {
    let configuration = JSON.parse(localStorage.getItem('configuration'));
    return doRequest(method, configuration.apiBaseUrl, path, data);
}

const doSelfRequest = async (method, path, data) => {
    return doRequest(method, '/', path, data);
}

const doBFFLogin = async () => {
    data = await doBFFRequest('POST', '/start', null);
    console.log('Login data', data);
    location.href = data['authRedirUrl']
}

const doBFFRefresh = async () => {
    data = await doBFFRequest('POST', '/refresh', null);
    console.log('Refresh data', data);
}

const doBFFLogout = async () => {
    data = await doBFFRequest('POST', '/logout', null);
    console.log('Logout data', data);
    location.href = data['logoutUrl']
}

const doBFFPageLoad = async (pageUrl) => {
    data = await doBFFRequest('POST', '/pageload', {pageUrl});
    console.log('Pageload data', data);
    if (data && 'loggedIn' in data && data['loggedIn']) {
	$('#loginState').html('Logged in (click "Get User Info" for more user data)').removeClass('boxed-red').addClass('boxed-green');
    } else {
	$('#loginState').html('Not logged in').removeClass('boxed-green').addClass('boxed-red');
    }
    if (data && 'handledAuth' in data && data['handledAuth']) {
	// The pageload finished the login, clear code from location
	history.replaceState({}, document.title, '/');
    }
}

const doBFFGetUserInfo = async () => {
    data = await doBFFRequest('GET', '/userinfo', null);
    console.log('Userinfo data', data);
    if (Object.keys(data).length === 0) {
	$('#userInfo').html('**ERROR** (tokens expired?)');
    } else {
	$('#loginState').html('Logged in as <b>'+data['preferred_username']+'</b>').removeClass('boxed-red').addClass('boxed-green');
	$('#userInfo').html(JSON.stringify(data, null, '  '));
    }
}

const doAPIWrite = async () => {
    let data = $('#objectData').val();
    console.log('API writing data', data);
    data = await doAPIRequest('POST', '/api/object', {data});
    console.log('API write response', data);
    if (data) {
	$('#objectList').html('');
	$('#objectDataInfo').html('**ERROR** (not logged in?)');
    } else {
	$('#objectDataInfo').html('**ERROR** (not logged in?)');
    }
}

const doAPIListObjects = async () => {
    data = await doAPIRequest('GET', '/api/objects', null);
    console.log('API list objects response', data);
    if (data) {
	$('#objectList').html(data.join('<br>'));
    } else {
	$('#objectList').html('**ERROR** (not logged in?)');
    }
}

async function ensureConfig() {
    if (! localStorage.getItem('configuration')) {
	console.log('Loading configuration');
	data = await doSelfRequest('GET', 'config.json', null);
	console.log('Config response', data);
	localStorage.setItem('configuration', JSON.stringify(data));
    }
    let configuration = JSON.parse(localStorage.getItem('configuration'));
    $('#configuration').html(JSON.stringify(configuration, null, '  '));
}

window.addEventListener('load', () => {
    $('#loginState').html('Unknown');
    $('#userInfo').html('No UserInfo. Click "Get User Info" above to read user info from BFF');

    $('#doLogin').click(doBFFLogin);
    $('#doLogout').click(doBFFLogout);
    $('#doGetUserInfo').click(doBFFGetUserInfo);
    $('#doRefreshTokens').click(doBFFRefresh);
    $('#doAPIWrite').click(doAPIWrite);
    $('#doAPIListObjects').click(doAPIListObjects);

    console.log('Location: ', location.href);

    ensureConfig();
    doBFFPageLoad(location.href);
});
