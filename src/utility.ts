type token = string | null;

const G = {
	csrfToken: null as token,
};

const do_api = (api: string, method: string, body?: string) =>
	fetch(`api/${api}`, {
		method,
		headers: {
			"Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
			"X_CSRF_TOKEN": G.csrfToken as string
		},
		body
	});

function setCSRFToken(token: token = null) { G.csrfToken = token; }

function GET(api: string) { return fetch(`api/${api}`); }
function POST(api: string, body: string) { return do_api(api, "POST", body); }
function PUT(api: string, body: string) { return do_api(api, "PUT", body); }
function PATCH(api: string, body: string) { return do_api(api, "PATCH", body); }
function DELETE(api: string) { return do_api(api, "DELETE"); }

(window as any).setCSRFToken = setCSRFToken;
(window as any).GET = GET;
(window as any).POST = POST;
(window as any).PUT = PUT;
(window as any).PATCH = PATCH;
(window as any).DELETE = DELETE;
