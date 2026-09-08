#!/usr/bin/env node
/**
 * build-rbxlx.mjs — turn the source tree into a Roblox place file.
 *
 * Rojo is the better long-term workflow, but it needs an install and a
 * plugin. This produces a .rbxlx you can double-click straight into Studio,
 * which is the difference between "clone this repo" and "play this game".
 *
 * The mapping matches default.project.json exactly, so the two stay
 * interchangeable:
 *   src/shared  -> ReplicatedStorage/Shared
 *   src/server  -> ServerScriptService/Server
 *   src/client  -> StarterPlayer/StarterPlayerScripts/Client
 *
 * Naming: Foo.luau -> ModuleScript "Foo"
 *         Foo.server.luau -> Script "Foo"
 *         Foo.client.luau -> LocalScript "Foo"
 */

import { readdirSync, readFileSync, statSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = join(ROOT, "build", "DeepRush.rbxlx");

let referent = 0;
const nextRef = () => `RBX${referent++}`;

/** XML-escape a text node. */
function esc(text) {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

/**
 * Luau source goes in a CDATA block so backslashes, quotes and Unicode
 * survive untouched. The one sequence CDATA cannot contain is "]]>", so we
 * refuse to build rather than emit a file Studio would silently truncate.
 */
function sourceNode(source, file) {
  if (source.includes("]]>")) {
    throw new Error(`${file} contains "]]>", which cannot go inside CDATA`);
  }
  return `<ProtectedString name="Source"><![CDATA[\n${source}\n]]></ProtectedString>`;
}

function classForFile(name) {
  if (name.endsWith(".server.luau")) return ["Script", name.slice(0, -".server.luau".length)];
  if (name.endsWith(".client.luau")) return ["LocalScript", name.slice(0, -".client.luau".length)];
  if (name.endsWith(".luau")) return ["ModuleScript", name.slice(0, -".luau".length)];
  return null;
}

const indent = (depth) => "  ".repeat(depth);

/** Recursively turn a directory into Folder + script Items. */
function buildTree(dir, depth) {
  const out = [];
  const entries = readdirSync(dir).sort();

  for (const entry of entries) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) {
      out.push(`${indent(depth)}<Item class="Folder" referent="${nextRef()}">`);
      out.push(`${indent(depth + 1)}<Properties>`);
      out.push(`${indent(depth + 2)}<string name="Name">${esc(entry)}</string>`);
      out.push(`${indent(depth + 1)}</Properties>`);
      out.push(buildTree(full, depth + 1));
      out.push(`${indent(depth)}</Item>`);
      continue;
    }

    const mapped = classForFile(entry);
    if (!mapped) continue;
    const [className, instanceName] = mapped;
    const source = readFileSync(full, "utf8");

    out.push(`${indent(depth)}<Item class="${className}" referent="${nextRef()}">`);
    out.push(`${indent(depth + 1)}<Properties>`);
    out.push(`${indent(depth + 2)}<string name="Name">${esc(instanceName)}</string>`);
    out.push(`${indent(depth + 2)}${sourceNode(source, entry)}`);
    out.push(`${indent(depth + 2)}<bool name="Disabled">false</bool>`);
    out.push(`${indent(depth + 1)}</Properties>`);
    out.push(`${indent(depth)}</Item>`);
  }

  return out.filter(Boolean).join("\n");
}

function folderWrapping(name, dir, depth) {
  return [
    `${indent(depth)}<Item class="Folder" referent="${nextRef()}">`,
    `${indent(depth + 1)}<Properties>`,
    `${indent(depth + 2)}<string name="Name">${esc(name)}</string>`,
    `${indent(depth + 1)}</Properties>`,
    buildTree(dir, depth + 1),
    `${indent(depth)}</Item>`,
  ].join("\n");
}

function service(className, depth, props = "", children = "") {
  return [
    `${indent(depth)}<Item class="${className}" referent="${nextRef()}">`,
    `${indent(depth + 1)}<Properties>`,
    `${indent(depth + 2)}<string name="Name">${className}</string>`,
    props,
    `${indent(depth + 1)}</Properties>`,
    children,
    `${indent(depth)}</Item>`,
  ]
    .filter(Boolean)
    .join("\n");
}

const lightingProps = [
  `${indent(3)}<Color3 name="Ambient"><R>0</R><G>0</G><B>0</B></Color3>`,
  `${indent(3)}<Color3 name="OutdoorAmbient"><R>0.27</R><G>0.27</G><B>0.31</B></Color3>`,
  `${indent(3)}<float name="Brightness">2</float>`,
  `${indent(3)}<float name="ClockTime">15</float>`,
  `${indent(3)}<bool name="GlobalShadows">true</bool>`,
  `${indent(3)}<float name="FogStart">60</float>`,
  `${indent(3)}<float name="FogEnd">420</float>`,
  `${indent(3)}<Color3 name="FogColor"><R>0.06</R><G>0.06</G><B>0.08</B></Color3>`,
].join("\n");

const starterPlayerScripts = [
  `${indent(2)}<Item class="StarterPlayerScripts" referent="${nextRef()}">`,
  `${indent(3)}<Properties>`,
  `${indent(4)}<string name="Name">StarterPlayerScripts</string>`,
  `${indent(3)}</Properties>`,
  folderWrapping("Client", join(ROOT, "src", "client"), 3),
  `${indent(2)}</Item>`,
].join("\n");

const document = [
  '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
  service("Workspace", 1),
  service("Lighting", 1, lightingProps),
  service("ReplicatedStorage", 1, "", folderWrapping("Shared", join(ROOT, "src", "shared"), 2)),
  service("ServerScriptService", 1, "", folderWrapping("Server", join(ROOT, "src", "server"), 2)),
  service("StarterPlayer", 1, "", starterPlayerScripts),
  "</roblox>",
  "",
].join("\n");

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, document, "utf8");

const kb = (Buffer.byteLength(document, "utf8") / 1024).toFixed(0);
console.log(`Wrote ${OUT} (${referent} instances, ${kb} KB)`);
