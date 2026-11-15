// Sätteri mdast plugin: resolves %%key%% tokens from src/data/refs.mjs in
// markdown text, code, link URLs, and MDX JSX string attributes.
// Unknown keys fail the build.
import { fileURLToPath } from 'node:url';
import { refs } from '../data/refs.mjs';

const TOKEN = /%%([a-z0-9-]+)%%/g;

function resolve(value, ctx) {
	return value.replace(TOKEN, (_, key) => {
		if (!Object.hasOwn(refs, key)) {
			const where = ctx.fileURL ? fileURLToPath(ctx.fileURL) : 'unknown file';
			throw new Error(`Unknown ref "%%${key}%%" in ${where}. Add it to src/data/refs.mjs.`);
		}
		return refs[key];
	});
}

function setResolved(node, field, ctx) {
	const value = node[field];
	if (typeof value !== 'string' || !value.includes('%%')) return;
	ctx.setField(node, field, resolve(value, ctx));
}

function resolveJsxAttributes(node, ctx) {
	for (const attr of node.attributes) {
		if (attr.type === 'mdxJsxAttribute' && typeof attr.value === 'string' && attr.value.includes('%%')) {
			ctx.setAttribute(node, attr.name, resolve(attr.value, ctx));
		}
	}
}

export const refsPlugin = {
	name: 'nix-mechanics-refs',
	text: (node, ctx) => setResolved(node, 'value', ctx),
	inlineCode: (node, ctx) => setResolved(node, 'value', ctx),
	code: (node, ctx) => setResolved(node, 'value', ctx),
	link: (node, ctx) => setResolved(node, 'url', ctx),
	definition: (node, ctx) => setResolved(node, 'url', ctx),
	mdxJsxFlowElement: resolveJsxAttributes,
	mdxJsxTextElement: resolveJsxAttributes,
};
