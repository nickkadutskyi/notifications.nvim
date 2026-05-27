-- tests/notifications/notification_spec.lua
local Notification = require("notifications.notification")
local NotificationsBus = require("notifications.notifications_bus")

describe("Notification", function()
    local original_do_notify

    before_each(function()
        -- Spy on the bus so we can verify notify() delegates
        original_do_notify = NotificationsBus.doNotify
        NotificationsBus.doNotify = function(n) end
    end)

    after_each(function()
        NotificationsBus.doNotify = original_do_notify
    end)

    describe("constructor overloads", function()
        it("new(groupId, title, content, level)", function()
            local n = Notification:new("main", "My Title", "body", vim.log.levels.WARN)
            assert.are.equal("My Title", n:getTitle())
            assert.are.equal("body", n:getContent())
            assert.are.equal(vim.log.levels.WARN, n:getLevel())
            assert.are.equal("main", n:getGroupId())
        end)

        it("new(groupId, content) → title empty, level INFO", function()
            local n = Notification:new("g1", "just content")
            assert.are.equal("", n:getTitle())
            assert.are.equal("just content", n:getContent())
            assert.are.equal(vim.log.levels.INFO, n:getLevel())
        end)

        it("new(groupId, content, level) legacy form", function()
            local n = Notification:new("g2", "legacy msg", vim.log.levels.ERROR)
            assert.are.equal("", n:getTitle())
            assert.are.equal("legacy msg", n:getContent())
            assert.are.equal(vim.log.levels.ERROR, n:getLevel())
        end)

        it("defaults title to empty string and level to INFO", function()
            local n = Notification:new("g", "msg")
            assert.are.equal("", n:getTitle())
            assert.are.equal(vim.log.levels.INFO, n:getLevel())
        end)
    end)

    describe("getters / setters (chainable)", function()
        it("setTitle returns self and supports subtitle overload", function()
            local n = Notification:new("g", "c")
            local ret = n:setTitle("T", "S")
            assert.are.equal(n, ret)
            assert.are.equal("T", n:getTitle())
            assert.are.equal("S", n:getSubtitle())
        end)

        it("setSubtitle returns self", function()
            local n = Notification:new("g", "c")
            local ret = n:setSubtitle("sub")
            assert.are.equal(n, ret)
            assert.are.equal("sub", n:getSubtitle())
        end)

        it("setContent returns self and updates value", function()
            local n = Notification:new("g", "old")
            local ret = n:setContent("new")
            assert.are.equal(n, ret)
            assert.are.equal("new", n:getContent())
        end)

        it("setIcon returns self", function()
            local n = Notification:new("g", "c")
            local ret = n:setIcon("")
            assert.are.equal(n, ret)
            assert.are.equal("", n:getIcon())
        end)
    end)

    describe("predicates", function()
        it("hasTitle is true when title or subtitle present", function()
            assert.is_true(Notification:new("g", "t", "c"):setTitle("hi"):hasTitle())
            assert.is_true(Notification:new("g", "c"):setSubtitle("s"):hasTitle())
            assert.is_false(Notification:new("g", "c"):hasTitle())
            assert.is_false(Notification:new("g", "   ", "   "):hasTitle())
        end)

        it("hasContent is false for whitespace-only or empty", function()
            assert.is_true(Notification:new("g", "real"):hasContent())
            assert.is_false(Notification:new("g", "   "):hasContent())
            assert.is_false(Notification:new("g", ""):hasContent())
        end)

        it("assertHasTitleOrContent succeeds when either present", function()
            assert.has_no.errors(function()
                Notification:new("g", "title", "body"):assertHasTitleOrContent()
            end)
            assert.has_no.errors(function()
                Notification:new("g", "", "body"):assertHasTitleOrContent()
            end)
        end)

        it("assertHasTitleOrContent throws when neither title nor content", function()
            local n = Notification:new("g", "   ", "")
            local ok, err = pcall(function() n:assertHasTitleOrContent() end)
            assert.is_false(ok)
            assert.matches("must have title or/and content", err)
        end)
    end)

    it("notify() delegates to NotificationsBus", function()
        local called = false
        local received
        NotificationsBus.doNotify = function(n)
            called = true
            received = n
        end

        local n = Notification:new("g", "msg")
        n:notify()

        assert.is_true(called)
        assert.are.equal(n, received)
    end)

    describe("metamethods", function()
        it("__tostring contains key fields", function()
            local n = Notification:new("grp", "T", "C", vim.log.levels.DEBUG)
            local s = tostring(n)
            assert.matches("Notification{id=%d+", s)
            assert.matches("groupId='grp'", s)
            assert.matches("title='T'", s)
            assert.matches("content='C'", s)
            assert.matches("level=1", s) -- DEBUG
        end)

        it("__eq compares by all relevant fields", function()
            local a = Notification:new("g", "t", "c", 2)
            local b = Notification:new("g", "t", "c", 2)
            -- different ids so not equal
            assert.is_false(a == b)

            -- manually craft an equal one by copying id is hard; instead test inequality cases
            assert.is_false(a == "not a notification")
            assert.is_false(a == { id = a.id })
        end)
    end)

    it("assigns monotonically increasing ids", function()
        local first = Notification:new("g", "a").id
        local second = Notification:new("g", "b").id
        assert.is_true(second > first)
        assert.is_number(first)
    end)
end)
