#!/usr/bin/env python3
import argparse
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=18765)
parser.add_argument('--log', required=True)
args = parser.parse_args()

class Fixture(BaseHTTPRequestHandler):
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        prompt = json.loads(body['input'])
        note = prompt['note']
        meanings = prompt['clarified_meanings']
        if 'antag = binds, no activation' in note and not meanings:
            result = {'clarifications': [{'excerpt': 'antag = binds, no activation', 'question': 'Does "antag" mean antagonist?'}], 'cards': []}
        else:
            cards = []
            for line in note.splitlines():
                if line.startswith('PK ='):
                    cards.append({'question': 'What does pharmacokinetics describe?', 'answer': 'What the body does to a drug.', 'excerpt': line})
                if line.startswith('ADME ='):
                    cards.append({'question': 'What does ADME stand for?', 'answer': line.split('=', 1)[1].strip(), 'excerpt': line})
            result = {'clarifications': [], 'cards': cards}
        with Path(args.log).open('a') as log:
            log.write(json.dumps({'path': self.path, 'model': body['model'], 'note': note, 'meanings': meanings, 'result': result}) + '\n')
        response = {'status': 'completed', 'output': [{'type': 'message', 'content': [{'type': 'output_text', 'text': json.dumps(result)}]}]}
        data = json.dumps(response).encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def log_message(self, *_):
        pass

print(f'Fixture listening on 127.0.0.1:{args.port}', flush=True)
HTTPServer(('127.0.0.1', args.port), Fixture).serve_forever()
