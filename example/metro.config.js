// Metro config that avoids external escape dependency
const { getDefaultConfig } = require('expo/metro-config')
const path = require('path')
const exclusionList = require('metro-config/src/defaults/exclusionList')
const pak = require('../package.json')

const root = path.resolve(__dirname, '..')
const modules = Object.keys(pak.peerDependencies || {})

function escapeForRegExp(input) {
  return input.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

/** @type {import('metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname)

// Watch the repo root so Metro picks up local changes
config.watchFolders = [root]

config.resolver = {
  ...(config.resolver || {}),
  // Ensure only one version for peerDependencies by blocking root copies
  blockList: exclusionList(
    modules.map((m) =>
      new RegExp(`^${escapeForRegExp(path.join(root, 'node_modules', m))}\/.*$`)
    )
  ),
  // Always use the example app's version of peer deps
  extraNodeModules: {
    ...(config.resolver?.extraNodeModules || {}),
    ...modules.reduce((acc, name) => {
      acc[name] = path.join(__dirname, 'node_modules', name)
      return acc
    }, {}),
  },
}

module.exports = config
