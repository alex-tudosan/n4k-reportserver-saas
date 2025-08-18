# Simple Guide: Kyverno n4k + Reports Server Testing

## What This Is

This guide explains how to test **Kyverno n4k** (a security tool) with **Reports Server** (a storage system) in simple terms. Think of it like testing a security guard system for your computer applications.

## The Big Picture

**What we're testing:**
- **Kyverno** = A security guard that checks if your applications follow safety rules
- **Reports Server** = A filing cabinet that keeps records of what the security guard found
- **Monitoring** = A dashboard that shows you how well everything is working

**Why we're testing:**
- To make sure the security system works properly
- To see how it performs under different loads
- To understand how much it costs to run
- To plan for real-world use

## Phase 1: Small Test (Start Here)

### What We're Doing
We're setting up a small test environment to see if everything works before spending more money on bigger tests.

### Why We're Starting Small
- **Cost**: Only about $113 per month (vs $2,773 for full test)
- **Risk**: If something goes wrong, we don't lose much money
- **Learning**: We can figure out what we need before scaling up
- **Validation**: Make sure everything works before investing more

### Step 1: Get Your Tools Ready

**What we're doing:** Installing the software tools we need to work with cloud computers.

**Why we're doing this:** We need these tools to create and manage our test environment.

**Commands to run:**
```bash
brew install awscli eksctl kubectl helm jq
```

**What should happen:** No errors, tools get installed successfully.

**What to check:** Type `aws --version` and `kubectl version` - both should show version numbers.

### Step 2: Set Up Your Cloud Account

**What we're doing:** Connecting to Amazon's cloud service (AWS) so we can create our test computers.

**Why we're doing this:** We need cloud computers to run our tests (we can't use your local computer for big tests).

**Commands to run:**
```bash
aws configure
export AWS_REGION=us-west-2
```

**What should happen:** 
- You'll be asked for your AWS access key, secret key, and region
- Enter your AWS credentials when prompted
- No error messages

**What to check:** Run `aws sts get-caller-identity` - it should show your AWS account information.

### Step 3: Create Your Test Environment

**What we're doing:** Creating a small group of computers in the cloud to run our security tests.

**Why we're doing this:** We need computers to run Kyverno, Reports Server, and our test applications.

**Commands to run:**
```bash
./phase1-setup.sh
```

**What should happen:**
- Script runs for about 10-15 minutes
- You'll see progress messages about creating computers
- You'll see messages about installing software
- No error messages

**What to check:** At the end, run `kubectl get nodes` - you should see 2 computers listed.

### Step 4: Run Your Tests

**What we're doing:** Running 19 different tests to make sure everything works correctly.

**Why we're doing this:** We need to verify that all parts of the system are working before we trust it.

**Commands to run:**
```bash
./phase1-test-cases.sh
```

**What should happen:**
- Script runs for about 5-10 minutes
- You'll see test results like "PASS" or "FAIL"
- Most tests should show "PASS"
- You might see a few "FAIL" tests (that's normal for some tests)

**What to check:** At the end, you should see a summary showing most tests passed.

### Step 5: Look at Your Results

**What we're doing:** Opening a web dashboard to see how your system is performing.

**Why we're doing this:** The dashboard shows you real-time information about how well everything is working.

**Commands to run:**
```bash
# Get the password for the dashboard
kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d ; echo

# Open the dashboard
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

**What should happen:**
- You'll get a password (write it down)
- The dashboard will open in your web browser
- You'll see graphs and charts showing system performance

**What to check:** 
- Dashboard loads without errors
- You can see graphs with data
- No error messages in the dashboard

### Step 6: Clean Up When Done

**What we're doing:** Removing the test environment to stop paying for it.

**Why we're doing this:** Cloud computers cost money, so we want to turn them off when we're done testing.

**Commands to run:**
```bash
./phase1-cleanup.sh
```

**What should happen:**
- Script will ask if you want to keep or delete the computers
- Choose "delete" to save money
- Computers will be removed from your cloud account

**What to check:** Run `kubectl get nodes` - should show no computers (or an error saying no cluster).

## What Each Test Does

### Test 1: Basic Installation
**What it does:** Checks if all the software installed correctly.
**Why it matters:** If software didn't install properly, nothing else will work.
**Expected result:** All software components are running.

### Test 2: Policy Enforcement
**What it does:** Creates a test application that breaks security rules and sees if Kyverno catches it.
**Why it matters:** This proves that the security guard is actually working.
**Expected result:** Kyverno should block the bad application and create a report.

### Test 3: Report Generation
**What it does:** Checks if the Reports Server is storing information about security violations.
**Why it matters:** We need to keep records of what the security guard found.
**Expected result:** Reports should be created and stored properly.

### Test 4: Monitoring
**What it does:** Verifies that the dashboard is collecting and displaying information.
**Why it matters:** We need to see how the system is performing in real-time.
**Expected result:** Dashboard should show graphs with data.

### Test 5: Performance
**What it does:** Measures how fast the system can process security checks.
**Why it matters:** In real-world use, the system needs to be fast enough.
**Expected result:** Response times should be reasonable (under a few seconds).

## Understanding the Results

### Good Results (What You Want to See)
- ✅ **All tests pass** - Everything is working correctly
- ✅ **No error messages** - System is healthy
- ✅ **Dashboard shows data** - Monitoring is working
- ✅ **Fast response times** - System is performing well
- ✅ **Low resource usage** - System isn't using too much computer power

### Warning Signs (What to Watch For)
- ⚠️ **Some tests fail** - May indicate configuration issues
- ⚠️ **Slow response times** - System might be overloaded
- ⚠️ **High resource usage** - System might be too expensive to run
- ⚠️ **Dashboard errors** - Monitoring might not be working properly

### Bad Results (What You Don't Want to See)
- ❌ **Many tests fail** - System has serious problems
- ❌ **System crashes** - Software isn't stable
- ❌ **Very slow performance** - System won't work in real-world use
- ❌ **High costs** - System might be too expensive

## Common Problems and Solutions

### Problem: "AWS credentials not configured"
**What it means:** Your cloud account isn't set up properly.
**Solution:** Run `aws configure` and enter your AWS account details.

### Problem: "eksctl not installed"
**What it means:** You're missing a required tool.
**Solution:** Run `brew install eksctl`.

### Problem: "Cluster creation fails"
**What it means:** Something went wrong creating the computers.
**Solution:** Check your AWS region and permissions, try again.

### Problem: "Pods stuck in pending"
**What it means:** Applications can't start because there's not enough computer power.
**Solution:** Wait a few minutes, or check if your computers have enough resources.

### Problem: "Can't access dashboard"
**What it means:** The monitoring dashboard isn't accessible.
**Solution:** Make sure you're using port-forward, not trying to access it directly.

## What to Do Next

### If Phase 1 Works Well
**Congratulations!** Your system is working correctly. You can now:

1. **Proceed to Phase 2** - Test with more computers (~$423/month)
2. **Customize the system** - Modify it for your specific needs
3. **Plan for production** - Use what you learned to plan real-world deployment

### If Phase 1 Has Problems
**Don't worry!** This is why we test small first. You can:

1. **Fix the problems** - Use the troubleshooting section above
2. **Try again** - Run the tests again after fixing issues
3. **Ask for help** - Get support from the community or documentation

## Cost Breakdown

### Phase 1 Costs (What You're Paying For)
- **EKS Control Plane**: ~$73/month (the management computer)
- **2 Small Computers**: ~$30/month (the computers running your tests)
- **Storage**: ~$10/month (space to store data)
- **Total**: ~$113/month

### How to Save Money
- **Use Spot instances** - Can save 50-70% (but computers can be taken away)
- **Turn off when not testing** - Only pay for what you use
- **Use smaller computers** - If your tests don't need much power
- **Clean up properly** - Make sure to delete everything when done

## Success Checklist

Before you consider Phase 1 complete, make sure you have:

- ✅ **All tools installed** and working
- ✅ **AWS account configured** and accessible
- ✅ **Test environment created** successfully
- ✅ **All tests passing** (or most of them)
- ✅ **Dashboard working** and showing data
- ✅ **No major errors** in the system
- ✅ **Performance acceptable** for your needs
- ✅ **Costs reasonable** for your budget

## Next Steps

### Phase 2: Medium Test
- **What**: Test with more computers (~800 applications)
- **Cost**: ~$423/month
- **Purpose**: See how the system performs under more load
- **When**: After Phase 1 is working perfectly

### Phase 3: Large Test
- **What**: Test with many computers (~12,000 applications)
- **Cost**: ~$2,773/month
- **Purpose**: Validate the system for real-world use
- **When**: After Phase 2 is working well

## Getting Help

If you get stuck:

1. **Check the troubleshooting section** above
2. **Look at the comprehensive guide** (COMPREHENSIVE_GUIDE.md)
3. **Check the logs** - Run `kubectl logs` to see what's happening
4. **Ask the community** - Many people have gone through this before

## Summary

This simple guide walked you through:
1. **Setting up your tools** - Getting ready to work with cloud computers
2. **Creating a test environment** - Building a small test system
3. **Running tests** - Making sure everything works correctly
4. **Looking at results** - Understanding how well the system performs
5. **Cleaning up** - Stopping the costs when you're done

The goal is to test your security system safely and cheaply before investing in a bigger setup. Take your time, follow the steps carefully, and don't hesitate to ask for help if you need it!

---

**Remember**: Start small, test thoroughly, and scale up only when you're confident everything works. This approach saves money and reduces risk! 🎯
