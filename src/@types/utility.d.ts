declare function setCSRFToken(token: token): void;

declare function GET(api: string): Promise<Response>;
declare function POST(api: string, body: string): Promise<Response>;
declare function PUT(api: string, body: string): Promise<Response>;
declare function PATCH(api: string, body: string): Promise<Response>;
declare function DELETE(api: string): Promise<Response>;
