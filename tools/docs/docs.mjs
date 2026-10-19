import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import MarkdownIt from 'markdown-it';
import GithubSlugger from 'github-slugger';
import { PDFDocument, PDFDict, PDFName, PDFString, PDFHexString } from 'pdf-lib';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const docs = path.join(root, 'docs');
const md = new MarkdownIt({ html: false, linkify: false, typographer: false });
const cache = new Map();
const relative = file => path.relative(root, file).replaceAll('\\', '/');
const external = href => /^(?:[a-z][a-z\d+.-]*:|\/\/)/i.test(href);
const inside = (file, dir) => file === dir || file.startsWith(dir + path.sep);

function inlineText(tokens) {
    return (tokens || []).map(token => token.type === 'image' ? inlineText(token.children) || token.content :
        token.children ? inlineText(token.children) : ['text', 'code_inline', 'html_inline'].includes(token.type) ? token.content :
            ['softbreak', 'hardbreak'].includes(token.type) ? '\n' : '').join('');
}

async function document(file) {
    if (cache.has(file)) return cache.get(file);
    const source = (await fs.readFile(file, 'utf8')).replace(/^\uFEFF/, '');
    const tokens = md.parse(source, {});
    const slugger = new GithubSlugger();
    const headings = new Set();
    const links = [];
    function collect(children, line) {
        for (const token of children || []) {
            const href = token.type === 'link_open' ? token.attrGet('href') : token.type === 'image' ? token.attrGet('src') : null;
            if (href !== null) links.push({ href, line, image: token.type === 'image' });
            collect(token.children, line);
        }
    }
    for (let i = 0; i < tokens.length; i++) {
        const token = tokens[i];
        if (token.type === 'heading_open') {
            const id = slugger.slug(inlineText(tokens[i + 1].children));
            token.attrSet('id', id);
            headings.add(id);
        }
        collect([token], (token.map?.[0] ?? 0) + 1);
    }
    const result = { tokens, headings, links };
    cache.set(file, result);
    return result;
}

function target(file, href) {
    const hash = href.indexOf('#');
    const beforeHash = hash < 0 ? href : href.slice(0, hash);
    const pathname = beforeHash.split('?')[0];
    const fragment = hash < 0 ? '' : decodeURIComponent(href.slice(hash + 1));
    const decoded = decodeURIComponent(pathname);
    const resolved = decoded ? path.resolve(path.dirname(file), decoded) : file;
    return { file: resolved, fragment };
}

async function markdownFiles(dir) {
    const result = [];
    for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
        const file = path.join(dir, entry.name);
        if (entry.isDirectory()) result.push(...await markdownFiles(file));
        else if (/\.md$/i.test(entry.name)) result.push(file);
    }
    return result.sort();
}

async function check() {
    const files = [path.join(root, 'README.md'), ...await markdownFiles(docs)];
    const errors = [];
    const userNames = new Set(files.filter(file => path.dirname(file) === docs && path.basename(file).toLowerCase() !== 'readme.md')
        .flatMap(file => [path.basename(file).toLowerCase(), path.basename(file, '.md').toLowerCase() + '.pdf']));
    for (const entry of await fs.readdir(root, { withFileTypes: true })) {
        if (entry.isFile() && userNames.has(entry.name.toLowerCase())) {
            errors.push(`${entry.name}: duplicate user documentation; keep only docs/${entry.name}`);
        }
    }
    for (const file of files) {
        const data = await document(file);
        for (const link of data.links) {
            if (external(link.href)) continue;
            try {
                const dest = target(file, link.href);
                if (!inside(dest.file, root)) throw new Error('link escapes the repository');
                const stat = await fs.stat(dest.file).catch(() => null);
                if (!stat) throw new Error(`local target does not exist: ${relative(dest.file)}`);
                if (path.dirname(file) === docs && inside(dest.file, path.join(docs, 'gelistirici'))) {
                    throw new Error('user documentation must use an online URL for developer documentation (not included in offline bundles)');
                }
                if (dest.fragment && /\.md$/i.test(dest.file)) {
                    const headings = (await document(dest.file)).headings;
                    // GitHub also accepts the user-content- prefix used in rendered anchors.
                    if (!headings.has(dest.fragment) && !(dest.fragment.startsWith('user-content-') && headings.has(dest.fragment.slice(13)))) {
                        throw new Error(`heading #${dest.fragment} not found in ${relative(dest.file)}; available: ${[...headings].map(id => '#' + id).join(', ')}`);
                    }
                }
            } catch (error) {
                errors.push(`${relative(file)}:${link.line}: [${link.href}] ${error.message}`);
            }
        }
    }
    if (errors.length) throw new Error(`Documentation link check failed (${errors.length}):\n${errors.join('\n')}`);
    console.log(`Documentation links OK: ${files.length} Markdown files (external URLs not requested).`);
}

const css = `@page { size: A4; margin: 18mm 16mm; }
body { font: 11pt/1.5 "Segoe UI", Arial, sans-serif; color: #17202a; overflow-wrap: anywhere; }
h1 { font-size: 22pt; } h2 { font-size: 16pt; } h3 { font-size: 13pt; }
h1,h2,h3,h4 { break-after: avoid; } a { color: #075c9c; text-decoration: underline; }
table { width: 100%; border-collapse: collapse; margin: 1em 0; font-size: 9pt; }
thead { display: table-header-group; } tr { break-inside: avoid; }
th,td { border: 1px solid #9ba9b5; padding: 5px 7px; text-align: left; } th { background: #edf2f7; }
pre { white-space: pre-wrap; background: #f3f5f7; padding: 10px; font-size: 8.5pt; }
code { font-family: Consolas, "Courier New", monospace; } img { max-width: 100%; }
blockquote { border-left: 3px solid #9ba9b5; margin-left: 0; padding-left: 12px; }`;

function runEdge(edge, args) {
    return new Promise((resolve, reject) => {
        const child = spawn(edge, args, { windowsHide: true, stdio: ['ignore', 'ignore', 'pipe'] });
        let stderr = '';
        child.stderr.on('data', chunk => { stderr = (stderr + chunk).slice(-8000); });
        const timer = setTimeout(() => {
            child.kill();
            reject(new Error('Edge PDF rendering timed out after 90 seconds. Close stuck headless Edge processes and retry.'));
        }, 90000);
        child.on('error', error => { clearTimeout(timer); reject(error); });
        child.on('exit', code => {
            clearTimeout(timer);
            if (code === 0) resolve();
            else reject(new Error(`Edge exited with code ${code}: ${stderr}`));
        });
    });
}

// Chromium serializes file links as absolute build-machine paths. Use a reserved
// origin while printing, then replace its PDF URI annotations with portable links.
async function portablePdf(input, output) {
    const pdf = await PDFDocument.load(await fs.readFile(input));
    for (const page of pdf.getPages()) {
        const annotations = page.node.Annots();
        if (!annotations) continue;
        for (let i = 0; i < annotations.size(); i++) {
            const annotation = pdf.context.lookup(annotations.get(i));
            const action = annotation.lookupMaybe(PDFName.of('A'), PDFDict);
            if (!action) continue;
            const uri = action.get(PDFName.of('URI'));
            if (!(uri instanceof PDFString || uri instanceof PDFHexString)) continue;
            const value = uri.decodeText();
            if (value.startsWith('https://eda-docs.invalid/')) {
                action.set(PDFName.of('URI'), PDFString.of(decodeURI(value.slice('https://eda-docs.invalid/'.length))));
            }
        }
    }
    await fs.writeFile(output, await pdf.save());
}

async function build(edge) {
    if (!edge) throw new Error('Edge executable path missing. Invoke Build-Docs.ps1 -EdgePath <msedge.exe>.');
    await fs.access(edge);
    const files = (await markdownFiles(docs)).filter(file => path.dirname(file) === docs);
    if (!files.length) throw new Error('No docs/*.md source files found.');
    const generated = new Set(files);
    const temp = await fs.mkdtemp(path.join(os.tmpdir(), 'eda-docs-'));
    try {
        for (const file of files) {
            const data = await document(file);
            async function mapLinks(tokens) {
                for (const token of tokens) {
                    const attr = token.type === 'link_open' ? 'href' : token.type === 'image' ? 'src' : null;
                    const href = attr ? token.attrGet(attr) : null;
                    if (href !== null && !external(href)) {
                        const dest = target(file, href);
                        if (token.type === 'link_open') {
                            if (href.startsWith('#')) { /* Preserve within-document destinations. */ }
                            else if (generated.has(dest.file) || (/\.pdf$/i.test(dest.file) && path.dirname(dest.file) === docs)) {
                                const name = path.basename(dest.file).replace(/\.md$/i, '.pdf');
                                token.attrSet(attr, `https://eda-docs.invalid/${encodeURIComponent(name)}${dest.fragment ? '#' + encodeURIComponent(dest.fragment) : ''}`);
                            } else {
                                throw new Error(`${relative(file)}: local link cannot be included in user PDFs: ${href}`);
                            }
                        } else {
                            if (!inside(dest.file, docs) || inside(dest.file, path.join(docs, 'gelistirici'))) throw new Error(`Image outside user docs: ${href}`);
                            await fs.access(dest.file);
                            token.attrSet(attr, pathToFileURL(dest.file).href);
                        }
                    }
                    if (token.children) await mapLinks(token.children);
                }
            }
            await mapLinks(data.tokens);
            const title = path.basename(file, '.md');
            const html = path.join(temp, title + '.html');
            const pdf = path.join(temp, title + '.pdf');
            await fs.writeFile(html, `<!doctype html><html lang="tr"><head><meta charset="utf-8"><title>${md.utils.escapeHtml(title)}</title><style>${css}</style></head><body>${md.renderer.render(data.tokens, md.options, {})}</body></html>`, 'utf8');
            await runEdge(edge, ['--headless=new', '--disable-gpu', '--no-pdf-header-footer', '--no-first-run', '--disable-extensions', '--disable-background-networking', '--allow-file-access-from-files', `--user-data-dir=${path.join(temp, 'profile')}`, `--print-to-pdf=${pdf}`, pathToFileURL(html).href]);
            const bytes = await fs.readFile(pdf).catch(() => { throw new Error(`Edge did not produce ${pdf}. Ensure Edge headless printing is permitted by policy.`); });
            if (!bytes.subarray(0, 5).equals(Buffer.from('%PDF-'))) throw new Error(`Edge produced invalid PDF for ${relative(file)}.`);
            const output = file.replace(/\.md$/i, '.pdf');
            await portablePdf(pdf, output);
            console.log(`PDF: ${relative(output)}`);
        }
    } finally {
        await fs.rm(temp, { recursive: true, force: true, maxRetries: 10, retryDelay: 300 });
    }
}

try {
    if (Number(process.versions.node.split('.')[0]) < 20) throw new Error('Node.js 20 or newer is required.');
    if (process.argv[2] === 'check') await check();
    else if (process.argv[2] === 'build') await build(process.argv[3]);
    else throw new Error('Usage: node tools/docs/docs.mjs check | build <Edge executable>');
} catch (error) {
    console.error(error.message);
    process.exitCode = 1;
}
