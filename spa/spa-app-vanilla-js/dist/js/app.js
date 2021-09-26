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
	//showError(error);
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
    data = await doBFFRequest('GET', '/start', null);
    console.log('Login data', data);
    location.href = data['authRedirUrl']
}

const doBFFLogout = async () => {
    data = await doBFFRequest('GET', '/logout', null);
    console.log('Logout data', data);
    location.href = data['logoutUrl']
}

const doBFFPageLoad = async (pageUrl) => {
    data = await doBFFRequest('POST', '/pageload', {pageUrl});
    console.log('Pageload data', data);
    if (data && 'loggedIn' in data && data['loggedIn']) {
	$('#loginState').html('Logged in (click "Get User Info" for more user data)');
    } else {
	$('#loginState').html('Not logged in');
    }
    if (data && 'handledAuth' in data && data['handledAuth']) {
	// The pageload finished the login, clear code from location
	history.replaceState({}, document.title, '/');
    }
}

const doBFFGetUserInfo = async () => {
    data = await doBFFRequest('GET', '/userinfo', null);
    console.log('Userinfo data', data);
    if ('preferred_username' in data) {
	$('#loginState').html('Logged in as <b>'+data['preferred_username']+'</b>');
	$('#userInfo').html(JSON.stringify(data, null, '  '));
    } else {
	$('#userInfo').html('');
    }
}

const doAPIWrite = async () => {
    let data = $('#objectData').val();
    console.log('API writing data', data);
    data = await doAPIRequest('POST', '/api/object', {data});
    console.log('API write response', data);
    $('#objectList').html('');
}

const doAPIListObjects = async () => {
    data = await doAPIRequest('GET', '/api/objects', null);
    console.log('API list objects response', data);
    $('#objectList').html(data.join('<br>'));
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
    $('#doAPIWrite').click(doAPIWrite);
    $('#doAPIListObjects').click(doAPIListObjects);

    console.log('Location: ', location.href);

    ensureConfig();
    doBFFPageLoad(location.href);
});
